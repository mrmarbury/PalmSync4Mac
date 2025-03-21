defmodule Palmsync4mac.Dlp.Param do
  import SimpleEnum

  defenum :dlp_open_flags,
    # Open database for reading (0x80)
    dlp_open_read: 128,
    # Open database for writing (0x40)
    dlp_open_readrite: 64,
    # Open database with exclusive access (0x20)
    dlp_open_exclusive: 32,
    # Show secret records (0x10)
    dlp_open_secret: 16,
    # Open database for reading and writing (equivalent to (#dlpOpenRead | #dlpOpenWrite)) (0xC0)
    dlp_open_read_write: 192

  defenum :db_types,
    datebook_db: "DatebookDB"

  defenum :dlp_call_definitions,
    # 0x20
    pi_dlp_arg_first_id: 32

  defenum(
    :dlp_functions,
    # range reserved for internal use (0x0F)
    dlp_reserved_func: 15,

    # DLP 1.0 FUNCTIONS START HERE (PalmOS v1.0) 
    dlp_func_read_user_info: 0x10,
    dlp_func_write_user_info: 0x11,
    dlp_func_read_sys_info: 0x12,
    dlp_func_get_sys_date_time: 0x13,
    dlp_func_set_sys_date_time: 0x14,
    dlp_func_read_storage_info: 0x15,
    dlp_func_read_db_list: 0x16,
    dlp_func_open_db: 0x17,
    dlp_func_create_db: 0x18,
    dlp_func_close_db: 0x19,
    dlp_func_delete_db: 0x1A,
    dlp_func_read_app_block: 0x1B,
    dlp_func_write_app_block: 0x1C,
    dlp_func_read_sort_block: 0x1D,
    dlp_func_write_sort_block: 0x1E,
    dlp_func_read_next_modified_rec: 0x1F,
    dlp_func_read_record: 0x20,
    dlp_func_write_record: 0x21,
    dlp_func_delete_record: 0x22,
    dlp_func_read_resource: 0x23,
    dlp_func_write_resource: 0x24,
    dlp_func_delete_resource: 0x25,
    dlp_func_clean_up_database: 0x26,
    dlp_func_reset_sync_flags: 0x27,
    dlp_func_call_application: 0x28,
    dlp_func_reset_system: 0x29,
    dlp_func_add_sync_log_entry: 0x2A,
    dlp_func_read_open_dbInfo: 0x2B,
    dlp_func_move_category: 0x2C,
    dlp_process_rPC: 0x2D,
    dlp_func_open_conduit: 0x2E,
    dlp_func_end_of_sync: 0x2F,
    dlp_func_reset_record_index: 0x30,
    dlp_func_read_record_iDList: 0x31,

    # DLP 1.1 FUNCTIONS ADDED HERE (Palm_oS v2.0 Personal: and Professional) 
    dlp_func_read_next_rec_in_category: 0x32,
    dlp_func_read_next_modified_rec_in_category: 0x33,
    dlp_func_read_app_preference: 0x34,
    dlp_func_write_app_preference: 0x35,
    dlp_func_read_net_sync_info: 0x36,
    dlp_func_write_net_sync_info: 0x37,
    dlp_func_read_feature: 0x38,

    # DLP 1.2 FUNCTIONS ADDED HERE (PalmOS v3.0) 
    dlp_func_find_db: 0x39,
    dlp_func_set_db_info: 0x3A,

    # DLP 1.3 FUNCTIONS ADDED HERE (Palm_oS v4.0) 
    dlp_loop_back_test: 0x3B,
    dlp_func_exp_slot_enumerate: 0x3C,
    dlp_func_exp_card_present: 0x3D,
    dlp_func_exp_card_info: 0x3E,
    dlp_func_vfs_custom_control: 0x3F,
    dlp_func_vfs_get_default_dir: 0x40,
    dlp_func_vfs_import_database_from_file: 0x41,
    dlp_func_vfs_export_database_to_file: 0x42,
    dlp_func_vfs_file_create: 0x43,
    dlp_func_vfs_file_open: 0x44,
    dlp_func_vfs_file_close: 0x45,
    dlp_func_vfs_file_write: 0x46,
    dlp_func_vfs_file_read: 0x47,
    dlp_func_vfs_file_delete: 0x48,
    dlp_func_vfs_file_rename: 0x49,
    dlp_func_vfs_file_eOF: 0x4A,
    dlp_func_vfs_file_tell: 0x4B,
    dlp_func_vfs_file_get_attributes: 0x4C,
    dlp_func_vfs_file_set_attributes: 0x4D,
    dlp_func_vfs_file_get_date: 0x4E,
    dlp_func_vfs_file_set_date: 0x4F,
    dlp_func_vfs_dir_create: 0x50,
    dlp_func_vfs_dir_entry_enumerate: 0x51,
    dlp_func_vfs_get_file: 0x52,
    dlp_func_vfs_put_file: 0x53,
    dlp_func_vfs_volume_format: 0x54,
    dlp_func_vfs_volume_enumerate: 0x55,
    dlp_func_vfs_volume_info: 0x56,
    dlp_func_vfs_volume_get_label: 0x57,
    dlp_func_vfs_volume_set_label: 0x58,
    dlp_func_vfs_volume_size: 0x59,
    dlp_func_vfs_file_seek: 0x5A,
    dlp_func_vfs_file_resize: 0x5B,
    dlp_func_vfs_file_size: 0x5C,

    # DLP 1.4 functions added here (Palm OS 5.2+: ie Tapwave Zodiac) 
    dlp_func_exp_slot_media_type: 0x5D,
    dlp_func_write_record_ex: 0x5E,
    dlp_func_write_resource_ex: 0x5F,
    dlp_func_read_record_ex: 0x60,
    dlp_func_unknown1: 0x61,
    dlp_func_unknown3: 0x62,
    dlp_func_unknown4: 0x63,
    dlp_func_read_resource_ex: 0x64,
    # FIXME: we don't know if that's the right value 
    dlp_last_func: 0x65
  )
end
