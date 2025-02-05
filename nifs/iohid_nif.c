#include "erl_nif.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/hid/IOHIDManager.h>

/*---------------------------------------------------------------------------
 * enumerate_devices/0
 *
 * Enumerates USB devices by matching on IORegistry classes.
 * It first tries "IOUSBHostDevice" (commonly used on newer macOS systems)
 * and falls back to "IOUSBDevice" if no devices are found.
 *
 * For each device found, it builds a string of the form:
 *
 *   "Product: <product>, Manufacturer: <manufacturer>, Vendor: <vendor>, Product ID: <product_id>"
 *
 * It returns an Erlang tuple:
 *
 *   {ok, [DeviceString1, DeviceString2, …]}
 *--------------------------------------------------------------------------*/
static ERL_NIF_TERM enumerate_devices(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    // Try matching "IOUSBHostDevice" first.
    CFMutableDictionaryRef matchingDict = IOServiceMatching("IOUSBHostDevice");
    if (!matchingDict) {
        return enif_make_tuple2(env,
                                enif_make_atom(env, "error"),
                                enif_make_string(env, "Failed to create matching dictionary for IOUSBHostDevice", ERL_NIF_LATIN1));
    }
    
    io_iterator_t iterator;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator);
    if (kr != KERN_SUCCESS) {
        return enif_make_tuple2(env,
                                enif_make_atom(env, "error"),
                                enif_make_string(env, "IOServiceGetMatchingServices failed for IOUSBHostDevice", ERL_NIF_LATIN1));
    }
    
    // Count devices in the iterator.
    CFIndex deviceCount = 0;
    {
        io_object_t dev;
        while ((dev = IOIteratorNext(iterator)) != 0) {
            deviceCount++;
            IOObjectRelease(dev);
        }
    }
    IOObjectRelease(iterator);
    
    // If no devices found with IOUSBHostDevice, try IOUSBDevice.
    if (deviceCount == 0) {
        matchingDict = IOServiceMatching("IOUSBDevice");
        if (!matchingDict) {
            return enif_make_tuple2(env,
                                    enif_make_atom(env, "error"),
                                    enif_make_string(env, "Failed to create matching dictionary for IOUSBDevice", ERL_NIF_LATIN1));
        }
        kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator);
        if (kr != KERN_SUCCESS) {
            return enif_make_tuple2(env,
                                    enif_make_atom(env, "error"),
                                    enif_make_string(env, "IOServiceGetMatchingServices failed for IOUSBDevice", ERL_NIF_LATIN1));
        }
    } else {
        // Re-obtain the iterator using IOUSBHostDevice.
        matchingDict = IOServiceMatching("IOUSBHostDevice");
        kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator);
        if (kr != KERN_SUCCESS) {
            return enif_make_tuple2(env,
                                    enif_make_atom(env, "error"),
                                    enif_make_string(env, "Failed to re-obtain iterator for IOUSBHostDevice", ERL_NIF_LATIN1));
        }
    }
    
    // Build an Erlang list of strings for each device.
    ERL_NIF_TERM devicesList = enif_make_list(env, 0);
    io_object_t device;
    while ((device = IOIteratorNext(iterator)) != 0) {
        // Retrieve properties for this USB device.
        CFStringRef productCF = IORegistryEntryCreateCFProperty(device, CFSTR("USB Product Name"), kCFAllocatorDefault, 0);
        CFStringRef manufacturerCF = IORegistryEntryCreateCFProperty(device, CFSTR("USB Vendor Name"), kCFAllocatorDefault, 0);
        CFNumberRef vendorIDCF = IORegistryEntryCreateCFProperty(device, CFSTR("idVendor"), kCFAllocatorDefault, 0);
        CFNumberRef productIDCF = IORegistryEntryCreateCFProperty(device, CFSTR("idProduct"), kCFAllocatorDefault, 0);
        
        // Use "Unknown" as the default value.
        char product[256] = "Unknown";
        char manufacturer[256] = "Unknown";
        char vendor[32] = "Unknown";
        char product_id[32] = "Unknown";
        
        if (productCF) {
            CFStringGetCString(productCF, product, sizeof(product), kCFStringEncodingUTF8);
        }
        if (manufacturerCF) {
            CFStringGetCString(manufacturerCF, manufacturer, sizeof(manufacturer), kCFStringEncodingUTF8);
        }
        if (vendorIDCF) {
            int v;
            if (CFNumberGetValue(vendorIDCF, kCFNumberIntType, &v)) {
                snprintf(vendor, sizeof(vendor), "%d", v);
            }
        }
        if (productIDCF) {
            int p;
            if (CFNumberGetValue(productIDCF, kCFNumberIntType, &p)) {
                snprintf(product_id, sizeof(product_id), "%d", p);
            }
        }
        
        // Build a string for this device.
        char deviceStr[1024];
        snprintf(deviceStr, sizeof(deviceStr),
                 "Product: %s, Manufacturer: %s, Vendor: %s, Product ID: %s",
                 product, manufacturer, vendor, product_id);
        
        ERL_NIF_TERM deviceTerm = enif_make_string(env, deviceStr, ERL_NIF_LATIN1);
        devicesList = enif_make_list_cell(env, deviceTerm, devicesList);
        
        if (productCF) CFRelease(productCF);
        if (manufacturerCF) CFRelease(manufacturerCF);
        if (vendorIDCF) CFRelease(vendorIDCF);
        if (productIDCF) CFRelease(productIDCF);
        
        IOObjectRelease(device);
    }
    IOObjectRelease(iterator);
    
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), devicesList);
}

/*---------------------------------------------------------------------------
 * send_data/3
 *
 * Given a vendor ID, product ID, and binary data, finds the first matching
 * HID device using the HID Manager and sends the data as an output report
 * (using report ID 0).
 *--------------------------------------------------------------------------*/
static ERL_NIF_TERM send_data(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    int targetVendor, targetProduct;
    if (!enif_get_int(env, argv[0], &targetVendor) || !enif_get_int(env, argv[1], &targetProduct)) {
         return enif_make_badarg(env);
    }
    ErlNifBinary bin;
    if (!enif_inspect_binary(env, argv[2], &bin)) {
         return enif_make_badarg(env);
    }

    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!manager) {
         return enif_make_tuple2(env,
                                 enif_make_atom(env, "error"),
                                 enif_make_string(env, "Failed to create HID manager", ERL_NIF_LATIN1));
    }

    // Create a matching dictionary for the desired vendor and product.
    CFMutableDictionaryRef matchingDict = CFDictionaryCreateMutable(kCFAllocatorDefault,
             0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFNumberRef vendorNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &targetVendor);
    CFNumberRef productNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &targetProduct);
    CFDictionarySetValue(matchingDict, CFSTR(kIOHIDVendorIDKey), vendorNumber);
    CFDictionarySetValue(matchingDict, CFSTR(kIOHIDProductIDKey), productNumber);
    IOHIDManagerSetDeviceMatching(manager, matchingDict);

    IOReturn openResult = IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone);
    if (openResult != kIOReturnSuccess) {
         CFRelease(vendorNumber);
         CFRelease(productNumber);
         CFRelease(matchingDict);
         CFRelease(manager);
         return enif_make_tuple2(env,
                                 enif_make_atom(env, "error"),
                                 enif_make_string(env, "Failed to open HID manager", ERL_NIF_LATIN1));
    }

    CFSetRef deviceSet = IOHIDManagerCopyDevices(manager);
    if (!deviceSet || CFSetGetCount(deviceSet) == 0) {
         if (deviceSet) CFRelease(deviceSet);
         CFRelease(vendorNumber);
         CFRelease(productNumber);
         CFRelease(matchingDict);
         CFRelease(manager);
         return enif_make_tuple2(env,
                                 enif_make_atom(env, "error"),
                                 enif_make_string(env, "No matching device found", ERL_NIF_LATIN1));
    }

    // Use the first matching device.
    IOHIDDeviceRef device = NULL;
    {
         CFIndex count = CFSetGetCount(deviceSet);
         IOHIDDeviceRef *deviceArray = malloc(count * sizeof(IOHIDDeviceRef));
         CFSetGetValues(deviceSet, (const void **)deviceArray);
         device = deviceArray[0];
         free(deviceArray);
    }

    IOReturn result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, bin.data, bin.size);

    CFRelease(deviceSet);
    CFRelease(vendorNumber);
    CFRelease(productNumber);
    CFRelease(matchingDict);
    CFRelease(manager);

    if (result == kIOReturnSuccess) {
         return enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_atom(env, "sent"));
    } else {
         char errorMsg[128];
         snprintf(errorMsg, sizeof(errorMsg), "Failed to send data: %d", result);
         return enif_make_tuple2(env,
                                 enif_make_atom(env, "error"),
                                 enif_make_string(env, errorMsg, ERL_NIF_LATIN1));
    }
}

/*---------------------------------------------------------------------------
 * NIF Function Registration and Initialization
 *--------------------------------------------------------------------------*/
static ErlNifFunc nif_funcs[] = {
    {"enumerate_devices", 0, enumerate_devices},
    {"send_data", 3, send_data}
};

ERL_NIF_INIT(Elixir.PalmSync4Mac.Communication.IOHidNif, nif_funcs, NULL, NULL, NULL, NULL)
