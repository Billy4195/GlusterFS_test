#!/bin/bash 

ssh-copy-id root@vm94
ssh-copy-id root@vm95
ssh-copy-id root@vm96

ssh root@vm94 echo "VM94 copy key success"
ssh root@vm95 echo "VM95 copy key success"
ssh root@vm96 echo "VM96 copy key success"
