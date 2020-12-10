# postgres-xl


```
IMAGE_NAME = "Centos/7"
N = 2

Vagrant.configure("2") do |config|
    config.ssh.insert_key = false
    config.vm.provision :shell, privileged: true, inline: $install_common_tools
    #config.vm.provision :docker
    config.vm.provider "virtualbox" do |v|
        v.customize ["modifyvm", :id, "--usb", "off"]
        v.memory = 2048
        v.cpus = 2
     end

  (1..4).each do |i|
    config.vm.define "knode#{i}" do |master|
        master.vm.box = IMAGE_NAME
        master.vm.network "private_network", ip: "192.168.50.2#{i}"
        master.vm.hostname = "knode#{i}"
    end
  end
end


$install_common_tools = <<-SCRIPT
### Customization
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

useradd  "postgres"  -m -s /bin/bash
sudo -u postgres ssh-keygen -t rsa -b 4096 -C "postgres@vagrant" -N '' -f ~postgres/.ssh/id_rsa &&
sudo -u postgres touch ~postgres/.ssh/authorized_keys && 
sudo -u postgres cat ~postgres/.ssh/id_rsa.pub >> ~postgres/.ssh/authorized_keys &&
sudo -u postgres cat ~postgres/.ssh/authorized_keys 
sudo -u postgres mkdir ~/postgres/pgxc_ctl
echo "postgres" | passwd --stdin postgres
echo ">>> Done"
echo '192.168.50.21 knode1 
192.168.50.22 knode2
192.168.50.23 knode3
192.168.50.24 knode4 > /etc/hosts 

yum install git 
yum install gcc make zlib readline-devel.x86_64 readline-devel.i386 ncurses-devel.i386 ncurses-devel.x86_64 flex bison bison build-essential daemontools flex libreadline-dev rsync netcat  zlib1g-dev -y 

# cd /tmp && rm -fr postgres-xl 
# cd /tmp && git clone http://gitlablex.ibasis.net/ssharma/postgres-xl.git
# cd postgres-xl
# ./configure  --without-zlib &&  make  &&  make install
# cd pgxc_ctl &&  make

SCRIPT

$pgxlconf = <<-SCRIPT
### setup 
# ssh-keygen -t rsa (Just press ENTER for all input values)
# cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
#  pgxc_ctl/pgxc_ctl.conf
pgxcOwner=postgres
pgxcUser=$pgxcOwner
pgxcInstallDir=/usr/local/pgsql

#gtm and gtmproxy
gtmMasterDir=$HOME/pgxc/nodes/gtm
gtmMasterPort=6666
gtmMasterServer=192.168.50.21
gtmSlave=n

#gtm proxy
gtmProxy=n

#coordinator
coordMasterDir=$HOME/pgxc/nodes/coord
coordNames=(coord1)
coordPorts=(5432)
poolerPorts=(6668)
coordPgHbaEntries=(192.168.50.0/24)
coordMasterServers=(192.168.50.22)
coordMasterDirs=($coordMasterDir/coord1)
coordMaxWALsernder=0
coordMaxWALSenders=($coordMaxWALsernder)
coordSlave=n
coordSpecificExtraConfig=(none none none)
coordSpecificExtraPgHba=(none none none)

#datanode
datanodeNames=(datanode1 datanode2)
datanodePorts=(15432 15433)
datanodePoolerPorts=(6669 6670)
datanodePgHbaEntries=(192.168.50.0/24)
datanodeMasterServers=(192.168.50.23 192.168.50.24)
datanodeMasterDir=$HOME/pgxc/nodes/dn_master
datanodeMasterDirs=($datanodeMasterDir/datanode1 $datanodeMasterDir/datanode2)
datanodeMaxWalSender=0
datanodeMaxWALSenders=($datanodeMaxWalSender $datanodeMaxWalSender)
datanodeSlave=n
primaryDatanode=datanode1
# EOF 

# sed -i 's/^# User.*/#UserSPECIFIC\nexport PATH=\/usr\/local\/pgsql\/bin:$PATH/' .bashrc 
# echo "export PATH=/usr/local/pgsql/bin:$PATH/" >>  .bashrc 
# pgxc_ctl init all 

export dataDirRoot=$HOME/DATA/pgxl/nodes
pgxc_ctl 
> prepare config empty 
> exit 
pgxc_ctl

# edit the pgxc_ctl/pgxc_ctl.conf file for the PgHbaEntries for allowing the subnet 192.168.50.0/24

# Adding Global Transaction manager 
> add gtm master gtm knode1 6666 $dataDirRoot/gtm
> monitor all

# Adding coordinator nodes 
> add coordinator master coord1 knode1 30001 30011 $dataDirRoot/coord_master.1 none none
> monitor all 
> add coordinator master coord2 knode1 30002 30012 $dataDirRoot/coord_master.2 none none
> monitor all 
## remove coordinator master coord2 # if you want to remove the coordinator 

# Adding data nodes 
> add datanode master dn1 knode1 40001 40011 $dataDirRoot/dn_master.1 none none none
> monitor all 
> add datanode master dn2 knode1 40002 40012 $dataDirRoot/dn_master.2 none none none
> monitor all 

# Setup is ready to login to 
psql -p 30001 postgres



# Add 3rd datanode 
pgxc_ctl
> add datanode master dn3 knode1 40003 40013 $dataDirRoot/dn_master.3 none none none
> monitor all 
# Add 3rd coordinator 
> add coordinator master coord3 knode1 30003 30013 $dataDirRoot/coord_master.3 none none
> monitor all 
> remove coordinator master coord3 clean
> monitor all 

# Remove data nodes - first remove all the tables from that data nodes 
> remove datanode master dn3 clean
> monitor all 


# Setting up slave data node for node1 
> add datanode slave dn1 knode1 40101 40111 $dataDirRoot/dn_slave.1 none $dataDirRoot/datanode_archlog.1
> monitor all 

# Failover of data node1 test 
> stop -m immediate datanode master dn1
> failover datanode dn1



> 
add coordinator master coord2 knode2 30002 30012 $dataDirRoot/coord_master.2 none none
remove coordinator master coord1 
add coordinator master coord1 knode2 30001 30011 $dataDirRoot/coord_master.1 none none
add datanode master dn1 knode3 40101 40111 $dataDirRoot/dn_slave.1 none none node
add datanode master dn2 knode4 40102 40112 $dataDirRoot/dn_slave.1 none node node 



### Testing create database running sql
# Connect to the coordinator node
psql -p 30001 -h knode2 postgres
CREATE DATABASE testdb;
psql -p 30001 -h knode2  testdb
SELECT * FROM pgxc_node;
CREATE TABLE disttab(col1 int, col2 int, col3 text) DISTRIBUTE BY HASH(col1);
\d+ disttab
CREATE TABLE repltab (col1 int, col2 int) DISTRIBUTE BY REPLICATION;
\d+ repltab

INSERT INTO disttab SELECT generate_series(1,100), generate_series(101, 200), 'foo';
INSERT INTO repltab SELECT generate_series(1,100), generate_series(101, 200);
SELECT count(*) FROM disttab;
SELECT xc_node_id, count(*) FROM disttab GROUP BY xc_node_id;
SELECT count(*) FROM repltab;
SELECT xc_node_id, count(*) FROM repltab GROUP BY xc_node_id;

ALTER TABLE disttab ADD NODE (dn3);



EXECUTE DIRECT ON(dn1) 'SELECT client_hostname, state, sync_state FROM pg_stat_replication';


# removing nodes and coordinators 
remove datanode master dn3 clean
remove coordinator master coord3 clean

# Adding slave nodes 
add datanode slave dn1 localhost 40101 40111 $dataDirRoot/dn_slave.1 none $dataDirRoot/datanode_archlog.1
# Stop a node 
stop -m immediate datanode master dn1
# Failover node 
failover datanode dn1




SCRIPT

```
