--
-- nanoart
-- license agreements.  See the NOTICE file distributed
-- https://www.jumpmind.com/blog/blog/performance/multi-homed-vs-remote-nodes/
--


------------------------------------------------------------------------------
-- Clear and load SymmetricDS Configuration
------------------------------------------------------------------------------

delete from sym_trigger_router;
delete from sym_trigger;
delete from sym_router;
-- there are a few system channels wich cannot be deleted
delete from sym_channel where channel_id in ('ds_ch1', 'ds_ch2');
delete from sym_node_group_link;
delete from sym_node_group;
delete from sym_node_host;
delete from sym_node_identity;
delete from sym_node_security;
delete from sym_node;

------------------------------------------------------------------------------
-- Channels
------------------------------------------------------------------------------

-- Channel "General" for tables related to sales and refunds
insert into sym_channel 
(channel_id, processing_order, max_batch_size, enabled, description)
values('ds_ch1', 1, 100000, 1, 'General');

-- Channel "item" for tables related to logs and task and reports
insert into sym_channel 
(channel_id, processing_order, max_batch_size, enabled, description)
values('ds_ch2', 1, 100000, 1, 'for logs and task and reports');

------------------------------------------------------------------------------
-- Node Groups
------------------------------------------------------------------------------

insert into sym_node_group (node_group_id, description) values ('master', 'The one group in a master to master cluster');


------------------------------------------------------------------------------
-- Node Group Links
------------------------------------------------------------------------------

-- push
insert into sym_node_group_link (source_node_group_id, target_node_group_id, data_event_action) values ('master', 'master', 'P');

------------------------------------------------------------------------------
-- Triggers
------------------------------------------------------------------------------

-- Triggers for tables on "item" channel
-- insert into sym_trigger 
-- (trigger_id,source_catalog_name, source_table_name,channel_id,last_update_time,create_time)
-- values('log','dualshield','log','ds_ch2',current_timestamp,current_timestamp);

-- role is a simple table no reference
insert into sym_trigger 
(trigger_id,source_catalog_name, source_table_name,channel_id,last_update_time,create_time)
values('role','dualshield', 'role','ds_ch1',current_timestamp,current_timestamp);

insert into sym_trigger 
(trigger_id,source_catalog_name, source_table_name,channel_id,last_update_time,create_time)
values('report','dualshield','report','ds_ch1',current_timestamp,current_timestamp);

------------------------------------------------------------------------------
-- Routers
------------------------------------------------------------------------------

-- Default router sends all data from corp to store 
insert into sym_router 
(router_id,source_node_group_id,target_node_group_id,router_type,create_time,last_update_time)
values('master_2_master', 'master', 'master', 'default',current_timestamp, current_timestamp);



------------------------------------------------------------------------------
-- Trigger Routers
------------------------------------------------------------------------------

-- Send all items to all stores
insert into sym_trigger_router 
(trigger_id,router_id,initial_load_order,last_update_time,create_time)
values('role','master_2_master', 100, current_timestamp, current_timestamp);


-- Send all items to all stores
insert into sym_trigger_router 
(trigger_id,router_id,initial_load_order,last_update_time,create_time)
values('report','master_2_master', 100, current_timestamp, current_timestamp);





