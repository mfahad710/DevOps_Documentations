# Logical Volume Management

- A method of flexible disk space management
- Ability to add disk space to a logical volume and its filesystem, while the filesystem is mounted and active.
- Allows multiple physical hard drives into a single Volume Group.
- Volume Groups can be partitioned into logical volumes

## LVM architecture 

The following are the components of LVM:

### Physical volume
A physical volume (**PV**) is a partition or whole disk designated for LVM use.

### Volume group
A volume group (**VG**) is a collection of physical volumes (PVs), which creates a pool of disk space out of which you can allocate logical volumes.

### Logical volume
A logical volume represents a usable storage device. For more information, see Basic logical volume management and Advanced logical volume management.

![LVM-Architecture](../Images/Linux/Logical-Volume-Management-Architecture.PNG)

## Commands

- disk partition information
    - fdisk -l
- Physical volume information
    - pvs
- To add disk
    - pvcreate <newdisk>
- Volume Group information
    - vgs
- Add added disk to Voume Group
    - vgextend vg_name newdisk
- Logical volume information
    - lvs
- Create Logical Volume on a free space
    - lvextend -l vg_name
- Available Block Devices
    - lsblk