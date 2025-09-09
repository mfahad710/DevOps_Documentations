# Disk Management Guide for Ubuntu

This guide provides step-by-step instructions to attach, partition, format, mount, persist, and unmount a new disk in Ubuntu.

## Check the Attached Disk

1. Verify the disk is attached:
```bash
lsblk
```

Found that `/dev/sdc` is attached

2. Confirm the disk has **no filesystem** (example: `/dev/sdc`):
```bash
sudo fdisk -l /dev/sdc
```
Look for a message like:

```bash
does not contain a valid partition table
```

## Partition the Disk

Run:
```bash
sudo fdisk /dev/sdc
```

Inside the `fdisk` interface:

- Press **n** → Create a new partition  
- Choose **p** → Primary partition  
- Press **Enter** → Accept default partition number (1)  
- Press **Enter** twice → Accept default start and end sectors (use entire disk)  
- Press **w** → Write changes and exit  

Verify the partition:
```bash
lsblk
```
You should now see `sdc1` under `sdc`

## Format the Partition

Format the newly created partition:
```bash
sudo mkfs.ext4 /dev/sdc1
```
> **This erases all data on the partition (if any)**

## Mount the Disk

1. Identify the disk:
```bash
lsblk
```

2. Create a mount point:
```bash
sudo mkdir -p /mnt/newdisk
```

3. Mount the disk:
```bash
sudo mount /dev/sdc1 /mnt/newdisk
```

4. Verify:
```bash
df -h
```
Look for `/dev/sdc1` in the output.


## Persist the Mount Across Reboots

1. Get the disk UUID:
```bash
sudo blkid /dev/sdc1
```

2. Edit `/etc/fstab`:
```bash
sudo nano /etc/fstab
```

3. Add a line at the end (replace `UUID` with the actual value):
```bash
UUID=xxxx-xxxx-xxxx-xxxx /mnt/newdisk ext4 defaults 0 2
```

4. Verify by mounting all:
```bash
sudo mount -a
```

5. Reboot and check:
```bash
sudo reboot
df -h
```

Ensure the disk persists at `/mnt/newdisk`.

## Unmount the Disk

1. Identify the mount point:
```bash
df -h
```

2. Unmount using the mount point:
```bash
sudo umount /mnt/newdisk
```

Or using device name:
```bash
sudo umount /dev/sdc1
```

3. Verify:
```bash
df -h
```
The disk should not appear.

4. (Optional) Remove from `/etc/fstab`:
```bash
sudo nano /etc/fstab
```
Comment or delete the disk entry.
