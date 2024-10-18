delete from sym_router;
delete from sym_node_group_link;
delete from sym_node_group;

insert into sym_node_group (node_group_id,description) 
 values ('regsvr','group that represents the registration server');
insert into sym_node_group (node_group_id,description) 
 values ('target','group that represents a target data source');
insert into sym_node_group (node_group_id,description) 
 values ('source1','group that represents a data source the provides data for the target.');
insert into sym_node_group (node_group_id,description) 
 values ('source2','group that represents a data source the provides data for the target.');
insert into sym_node_group (node_group_id,description) 
 values ('source3','group that represents a data source the provides data for the target.');
insert into sym_node_group (node_group_id,description) 
 values ('source4','group that represents a data source the provides data for the target.');
insert into sym_node_group (node_group_id,description) 
 values ('source5','group that represents a data source the provides data for the target.');
insert into sym_node_group (node_group_id,description) 
 values ('source6','group that represents a data source the provides data for the target.');
insert into sym_node_group (node_group_id,description) 
 values ('source7','group that represents a data source the provides data for the target.');
 
delete from sym_node_group_link;
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('target','regsvr','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('regsvr','target','W');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source1','regsvr','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('regsvr','source1','W');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source2','regsvr','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('regsvr','source2','W');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source3','regsvr','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('regsvr','source3','W');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source4','regsvr','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('regsvr','source4','W');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source5','regsvr','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('regsvr','source5','W');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source6','regsvr','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('regsvr','source6','W');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source7','regsvr','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('regsvr','source7','W');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source1','target','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source2','target','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source3','target','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source4','target','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source5','target','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source6','target','P');
insert into sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) 
 values ('source7','target','P');

insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('source1_to_target','source1','target','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('source2_to_target','source2','target','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('source3_to_target','source3','target','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('source4_to_target','source4','target','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('source5_to_target','source5','target','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('source6_to_target','source6','target','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
insert into sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) 
 values ('source7_to_target','source7','target','default',null,1,1,1,0,current_timestamp,'console',current_timestamp);
  