# Use SymmetricDS to do master-master replication on MySQL database


## Scenarios
### Node temporarily down

Node 1 (registration node) is down, change on Node 2 can be replicated to Node 3. Once Node 1 is back online, change is also replicated on it.

###  Update a row which doesn't exist on target node

The behavior: a new row was inserted on the target node.

## The last resort for conflict

truncate your `sym_data`, `sym_data_event`, and `sym_outgoing_batch` tables. See the details in [How to Migrate a Busy Database](https://www.jumpmind.com/blog/blog/how-to/how-to-migrate-a-busy-database/)

## Utility `dbcompare`

It may not work between instances, as it need to specify the source and target engine properites file. However in Pro UI, I can select the remote node, but the comparison always in pending.

 
![alt text](./doc/cmp-nodes.png)

![alt text](./doc/cmp-setting.png)

![alt text](./doc/cmp-on.png)

![alt text](./doc/cmp-tables.png)

## auto.resolve

```
auto.resolve.foreign.key.violation
auto.resolve.foreign.key.violation.delete
auto.resolve.foreign.key.violation.reverse
auto.resolve.primary.key.violation
auto.resolve.unique.index.violation
```

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