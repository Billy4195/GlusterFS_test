# GlusterFS_test

This test tool can be used to test the GlusterFS' disperse(erasure coding) volume

For three type of test :

1. Reboot
2. Replace brick
3. Network disconnect

After each event execute, it will wait for the volume heal finished then execute next action. 

###### *For convenience, following use "EC" represent disperse volume*

## Requirement
  * a EC volume
  * an additional server (For running test script)
  * a VG has enough space to create a brick ( as one of EC volume's bricks )

---
## How to use
**All the operation is only for the test host ( The additional server )**

### Install
  
    git clone https://github.com/Billy4195/GlusterFS_test.git
  
### Check for hosts setting
  
  * check /etc/hosts have volume's host
  * check /etc/hosts have self host at last line of the file
  * check ~/.ssh/id_rsa.pub exist

### First time to execute

    sh key_set.sh
  
### Start testing

    sh integration_test.sh <volume_name>
    
then type in 
* number of test ( default = 1 )
* number of RW_test ( default = 3 )
* file size for RW_test ( default = 10 )


###*Testing the volume!*
    
