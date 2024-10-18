delete from sym_router;
delete from sym_node_group_link;
delete from sym_node_group;
delete from sym_node_identity;
delete from sym_node_security;
delete from sym_node;

insert into sym_node_group (node_group_id,description) 
 values ('cloud','group that represents the cloud node');
insert into sym_node_group (node_group_id,description) 
 values ('onprem','group that represents the registration server and the on prem node');

insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('onprem','cloud','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('cloud','onprem','W');

insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('onprem pushes to cloud','onprem','cloud','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
 
insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('cloud waits for pull from onprem','cloud','onprem','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
  