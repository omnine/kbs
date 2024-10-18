delete from sym_router;
delete from sym_node_group_link;
delete from sym_node_group;
delete from sym_node_identity;
delete from sym_node_security;
delete from sym_node;
delete from sym_parameter;

insert into sym_node_group (node_group_id,description) 
 values ('master','The one group in a master to master cluster');

insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('master','master','P');

insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('master_2_master','master','master','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
 
insert into sym_parameter (external_id, node_group_id, param_key, param_value, create_time, last_update_by, last_update_time) 
 values ('ALL','ALL','push.thread.per.server.count','10',current_timestamp,'console',current_timestamp);
