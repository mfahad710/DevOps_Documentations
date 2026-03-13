# Linux NFS Server
Network File Sharing (NFS) is a protocol that allows you to share directories and files with other Linux clients over a network. Shared directories are typically created on a file server, running the NFS server component. Users add files to them, which are then shared with other users who have access to the folder.

An NFS file share is mounted on a client machine, making it available just like folders the user created locally. NFS is particularly useful when disk space is limited and you need to exchange public data between client computers

## 1. Setting Up an NFS Server with an NFS Share

### Install NFS Package in NFS Server

On Ubuntu and Debian:
```bash
sudo apt-get update
sudo apt-get install nfs-kernel-server -y
```

On CentOS and Fedora:
```bash
yum -y install nfs-utils
```

### Create NFS Directory to be used for Sharing
```bash
sudo mkdir -p /nfs_share
sudo chown -R nobody:nogroup /nfs_share
sudo chmod 777 /nfs_share
```

### Export File
To grant access to NFS clients, we’ll need to define an export file. The file is typically located at `/etc/exports`  
Edit the `/etc/exports` file to add the NFS share, and ensure the nodes/computers can access it.

**To enable access to a single client**
```bash
echo "/nfs_share <client_ip>(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
```

**To enable access to several clients**
```bash
echo "/nfs_share <client_ip1>(rw,sync,no_subtree_check) <client_ip2>(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
```

**To enable access to an entire subnet**
```bash
echo "/nfs_share <subnet_ip>/24(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
```

- `rw`: which enables both read and write
- `sync`: which writes changes to disk before allowing users to access the modified file
- `no_subtree_check`: which means NFS doesn’t check if each subdirectory is accessible to the user.

### Make the NFS Share Available to Clients

Make the shared directory available to clients using the `exportfs` command. After running this command, the NFS Kernel should be restarted.

```bash
sudo exportfs -a
```

### Restart the NFS server to apply the changes
```bash
sudo systemctl restart nfs-kernel-server
```


## 2. Setting Up NFS on Client Machine and Mounting an NFS Share
Now that we have set up the NFS server, let’s see how to share a folder, defined as an NFS share, with a Linux computer by mounting it on the local machine.

### Installing NFS Client Packages
Here are the packages you need to install to enable mounting an NFS share on a local Linux machine.

On Ubuntu and Debian:
```bash
sudo apt update
sudo apt install nfs-common
```

On CentOS and Fedora:
```bash
sudo yum install nfs-utils
```

### Mounting the NFS File Share Temporarily

We can mount the NFS folder to a specific location on the local machine, known as a mount point, using the following commands.  

Create a local directory this will be the mount point for the NFS share. In our example we’ll call the folder /var/locally-mounted.

```bash
sudo mkdir /var/locally-mounted
```

Mount the file share by running the mount command, as follows. There is no output if the command is successful.
```bash
sudo mount -t nfs {IP of NFS server}:{folder path on server} /var/locally-mounted
```

For example:
```bash
sudo mount -t nfs 192.168.20.100:/nfs_share /var/locally-mounted
```

The mount point now becomes the root of the mounted file share, and under it we should find all the subdirectories stored in the NFS file share on the server.

To verify that the NFS share is mounted successfully, run the `mount` command or `df -h`

### Mounting NFS File Shares Permanently

Remote NFS directories can be automatically mounted when the local system is started. You can define this in the `/etc/fstab` file. In order to ensure an NFS file share is mounted locally on startup, you need to add a line to this file with the relevant file share details.

To automatically mount NFS shares on Linux, do the following:

Create a local directory that will be used to mount the file share.
```bash
sudo mkdir /var/locally-mounted
```

Edit the `/etc/fstab` file using the `nano` or any text editor.

Add a line defining the NFS share. Insert a tab character between each parameter. It should appear as one line with no line breaks.

```bash
{IP of NFS server}:{folder path on server} /var/locally-mounted nfs defaults 0 0
```

for example:
```bash
192.168.20.100:/nfs_share /var/locally-mounted nfs defaults 0 0
```

The last three parameters indicate NFS options (which we set to default), dumping of file system and filesystem check (these are typically not used so we set them to 0).

Now mount the file share using the following command. The next time the system starts, the folder will be mounted automatically.

```bash
mount /var/locally-mounted
mount {IP of NFS server}:{folder path on server}
```

For example:
```bash
mount /var/locally-mounted
mount 192.168.20.100:/nfs_share
```
