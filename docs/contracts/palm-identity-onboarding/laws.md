# User Identity Onboarding — Laws for username and user_id

How to read this file:

- Bulleted rules are global laws. All global laws must be true together.
- Numbered rules are one decision tree. Exactly one numbered branch must be
  true for each device.
- The state names KNOWN, ADOPT, ONBOARD, RE_ONBOARD are
  the states of the onboarding contract.

## Global laws

- If a PALM needs onboarding, the onboarding happens during the pre-sync.
- The username is the identity key of a palm_user row.
- The system compares usernames byte for byte. The system does not trim a
  username and does not change its case.
- A username must identify not more than one palm_user row. The database
  checks this eagerly on every upsert, because the username is the upsert
  key.
- A user_id must identify not more than one palm_user row. The database
  holds a unique index on user_id. The database does not check this eagerly.
  The index stops an onboarding race as an error, not as a duplicate.
- The database must set the user_id. The device must not set its own
  user_id. (A fresh device reads user_id 0. Foreign tools can rewrite the
  device user_id.)
- The new user_id must be one more than the largest user_id in the
  palm_user table. The new user_id must not be less than 1. The assignment
  must run in one transaction.
- The system must not change the username or the user_id of a row after the
  system creates the row.
- The system must not write a different username to a device that already
  has a name. (Established devices silently drop username writes.)
- A device is nameless if its username is empty or holds whitespace bytes
  only.
- An explicit username must hold 1 to 40 bytes. Every byte must be in the
  printable ASCII range 0x20 to 0x7E. At least one byte must not be a
  whitespace byte.
- If the explicit username is not valid, the pre-sync must stop with the
  error :username_invalid. The system must not create a row. The system
  must not write a byte to the device.
- The system must not generate a username. (The username is permanent on
  Palm hardware. Only the user can choose the username consciously.)
- A completed onboarding must return the palm_user_id of an existing row. A
  nil palm_user_id must never go to the sync workers.

## Classification decision tree

1. For every PALM device, if an explicit username is given and the username
   is not valid, the pre-sync stops with the error :username_invalid. No
   row is created. No byte goes to the device. This rule applies before
   rule 2 and rule 3.

2. For every PALM device that has a name:
   1. If a palm_user row holds the same username byte for byte, the device
      classifies as KNOWN. The system does not write identity data to the
      device. If the device user_id is different from the row user_id, the
      system logs a warning. The name stays the identity. (Two physical
      devices can share one name. This is a documented gap.)
   2. If no palm_user row holds the same username, the device classifies
      as ADOPT. The system creates a row with the device name and an
      assigned user_id. The system writes the user_id to the device. If
      this write fails, the system logs a warning and the sync continues.
      The name stays the identity.

3. For every PALM device that is nameless:
   1. If a valid explicit username is given:
      1. If a palm_user row holds the same username, the device classifies
         as RE_ONBOARD. The system writes the row username and the row
         user_id to the device first. If the device write fails, the sync
         stops with the error :device_write_failed. No row changes. If the
         device write succeeds, the system deletes all join rows of the
         row. If one or more join rows stay, the sync stops with the error
         :join_row_reset_incomplete.
      2. If no palm_user row holds the same username, the device
         classifies as ONBOARD. The system creates the row first. Then the
         system writes the username and the user_id to the device. If the
         device write fails, the system deletes the new row. The sync
         stops with the error :device_write_failed.
   2. If no explicit username is given, the pre-sync stops with the error
      :username_required. No row is created. No byte goes to the device.
      (The username is permanent on Palm hardware. The user must choose the
      username consciously.)
