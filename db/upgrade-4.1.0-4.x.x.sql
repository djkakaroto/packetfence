---
--- Add a column to store the time balance of a node
---
ALTER TABLE node ADD `time_balance` int unsigned AFTER `lastskip`;

---
--- Add a column to store the bandwidth balance of a node
---
ALTER TABLE node ADD `bandwidth_balance` int unsigned AFTER `time_balance`;

--
-- Added a new columns to store in person field
--

ALTER TABLE person 
  ADD `anniversary` varchar(255) NULL DEFAULT NULL,
  ADD `birthday` varchar(255) NULL DEFAULT NULL,
  ADD `gender` char(1) NULL DEFAULT NULL,
  ADD `lang` varchar(255) NULL DEFAULT NULL,
  ADD `nickname` varchar(255) NULL DEFAULT NULL,
  ADD `cell_phone` varchar(255) NULL DEFAULT NULL,
  ADD `work_phone` varchar(255) NULL DEFAULT NULL,
  ADD `title` varchar(255) NULL DEFAULT NULL,
  ADD `building_number` varchar(255) NULL DEFAULT NULL,
  ADD `apartment_number` varchar(255) NULL DEFAULT NULL,
  ADD `room_number` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_1` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_2` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_3` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_4` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_5` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_6` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_7` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_8` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_9` varchar(255) NULL DEFAULT NULL
;