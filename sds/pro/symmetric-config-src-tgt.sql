delete from sym_router;
delete from sym_node_group_link;
delete from sym_node_group;
delete from sym_node_identity;
delete from sym_node_security;
delete from sym_node;

insert into sym_node_group (node_group_id,description) 
 values ('source','group that represents the registration server and source node');
insert into sym_node_group (node_group_id,description) 
 values ('target','group that represents multiple target nodes');

insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('target','source','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source','target','W');

insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('source waits for pull from target','source','target','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
 
insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('target pushes to source','target','source','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
  