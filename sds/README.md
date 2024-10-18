# Use SymmetricDS to do master-master replication on MySQL database

## The last resort for conflict

truncate your `sym_data`, `sym_data_event`, and `sym_outgoing_batch` tables. See the details in [How to Migrate a Busy Database](https://www.jumpmind.com/blog/blog/how-to/how-to-migrate-a-busy-database/)

## Utility `dbcompare`

It may not work between instances, as it need to specify the source and target engine properites file. However in Pro UI, I can select the remote node, but the comparison always in pending.

 
![alt text](./doc/cmp-nodes.png)

![alt text](./doc/cmp-setting.png)

![alt text](./doc/cmp-on.png)

![alt text](./doc/cmp-tables.png)


## Pro WEB screenshots
![Dashboard](./doc/sym-dashboard.png)  
![alt text](./doc/sym-manage.png)  
![alt text](./doc/sym-design.png)  
![alt text](./doc/sym-configure.png)  
![alt text](./doc/sym-explore.png)  


## References

https://stackoverflow.com/questions/78041207/how-to-change-locate-service-sym-tables-to-another-database 

[Pausing Replication In SymmetricDS](https://www.jumpmind.com/blog/blog/how-to/pausing-replication-symmetricds/)  
[Using Wildcards to Sync Database Tables](https://www.jumpmind.com/blog/blog/how-to/using-wildcards-sync-database/)
[Stop Guessing if Your Data is Correct](https://www.jumpmind.com/blog/blog/how-to/stop-guessing-if-your-data-is-correct/)