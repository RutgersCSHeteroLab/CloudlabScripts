#!/bin/bash

HOMEDIR=$HOME

#
SCRIPTS=$PWD

#Set your disk partitions
DISK=$HOME
DISK_DEVICE="/dev/sdc"
DISK_PARTITION="/dev/sdc1"

#Number of processors to use during setup
echo "Using $NPROC cores for setup"

#All downloads and code installation will happen here. 
#Feel free to change
CLOUDLABDIR=$DISK/cloudlab

LEVELDBHOME=$CLOUDLABDIR/leveldb-nvm
YCSBHOME=$CLOUDLABDIR/leveldb-nvm/mapkeeper/ycsb/YCSB

#LIBS Specific to IB
MVAPICHVER="mvapich2-2.3.4"
#Download URL
MVAPICHURL="http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/$MVAPICHVER.tar.gz"
MVAPICHPATH=$CLOUDLABDIR/$MVAPICHVER
MVAPICHBENCH=$MVAPICHPATH/osu_benchmarks
MPIPROCS=4 #Number of process to test


#Create the CLOUDLABDIR directory
mkdir $CLOUDLABDIR

MVAPICHPATH=$CLOUDLABDIR/$MVAPICHVER

#Create the CLOUDLABDIR directory
mkdir $CLOUDLABDIR

COOL_DOWN() {
	sleep 5
}

FORMAT_DISK() {
    DISK=$HOME/ssd
    mkdir $DISK
    sudo mount $DISK_PARTITION $DISK
    if [ $? -eq 0 ]; then
        sudo chown -R $USER $DISK
        echo OK
    else
        sudo fdisk $DISK_DEVICE
        sudo mkfs.ext4 $DISK_PARTITION
        sudo mount $DISK_PARTITION $DISK
        sudo chown -R $USER $DISK
    fi
}

INSTALL_FOLLY(){
cd $HOMEDIR/cloudlab/bistro/bistro/build/deps/fbthrift/thrift/build/deps/folly/folly
sudo apt-get install -y \
    g++ \
    automake \
    autoconf \
    autoconf-archive \
    libtool \
    libboost-all-dev \
    libevent-dev \
    libdouble-conversion-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    liblz4-dev \
    liblzma-dev \
    libsnappy-dev \
    make \
    zlib1g-dev \
    binutils-dev \
    libjemalloc-dev \
    libssl-dev

sudo apt-get install -y \
    libiberty-dev

  autoreconf -ivf
  ./configure
  make -j16
  #make check
  sudo make install
}

BUILD_BISTRO(){
    echo "hello"
    export PATH=$PATH:$CLOUDLABDIR/bistro/bistro/build/deps/fbthrift
    cd $CLOUDLABDIR/bistro/bistro/build
    sed -i "/googletest.googlecode/c\wget http://downloads.sourceforge.net/project/mxedeps/gtest-1.7.0.zip -O gtest-1.7.0.zip" $CLOUDLABDIR/bistro/bistro/build/build.sh
    ./build.sh Debug runtests
}



INSTALL_CASANDARA_SOURCE(){

    mkdir $CLOUDLABDIR/cassandra
    cd $CLOUDLABDIR/cassandra

    if [ ! -d "/usr/share/cassandra" ]; then
        INSTALL_CASANDARA_BINARY
    fi

    if [ ! -d "apache-cassandra-3.9-src" ]; then
        DOWNLOAD_CASANDARA_SOURCE
    fi	

    cd apache-cassandra-3.9*
    ant
    #keep a backup if installed version exists and no backup exists
    if [ ! -d "/usr/share/cassandra-orig" ]; then
        sudo cp -rf  /usr/share/cassandra  /usr/share/cassandra-orig
    fi
    sudo cp ./build/apache-cassandra-3.9-SNAPSHOT.jar /usr/share/cassandra/apache-cassandra-3.9.jar
    sudo cp ./build/apache-cassandra-thrift-3.9-SNAPSHOT.jar /usr/share/cassandra/apache-cassandra-thrift-3.9.jar
}

RUN_YCSB_CASSANDARA() {

    INSTALL_CASANDARA_SOURCE

    cd $YCSBHOME/cassandra
    ./start_sevice.sh 
}

INSTALL_JAVA() {
    sudo add-apt-repository ppa:webupd8team/java
    sudo apt-get update
    sudo apt-get install -y oracle-java8-set-default
    java -version
}

INSTALL_CMAKE(){
    cd $CLOUDLABDIR
    wget https://cmake.org/files/v3.7/cmake-3.7.0-rc3.tar.gz
    tar zxvf cmake-3.7.0-rc3.tar.gz
    cd cmake-3.7.0*
    ./configure
    ./bootstrap
    make -j16
    make install
}


INSTALL_SYSTEM_LIBS(){
	sudo apt-get update
	sudo apt-get install -y git
	sudo apt-get install -y kernel-package
	sudo apt-get install -y software-properties-common
	sudo apt-get install -y python3-software-properties
	sudo apt-get install -y python-software-properties
	sudo apt-get install -y unzip
	sudo apt-get install -y python-setuptools python-dev build-essential
	sudo easy_install pip
	sudo apt-get install -y numactl
	sudo apt-get install -y libsqlite3-dev
	sudo apt-get install -y libnuma-dev
	sudo apt-get install -y libkrb5-dev
	sudo apt-get install -y libsasl2-dev
	sudo apt-get install -y cmake
	sudo apt-get install -y build-essential
	sudo apt-get install -y maven
	sudo apt-get install -y mosh
	#sudo pip install thrift_compiler
}

#IB libs
INSTALL_IB_LIBS() {
	sudo apt-get install -y libibmad-dev libibumad-dev libibumad3
	sudo apt-get install -y libibverbs-dev
	sudo apt-get install -y gfortran
	sudo apt-get install -y infiniband-diags
	sudo apt-get install -y libnes-dev libmlx5-dev libmlx4-dev libmlx5-dev libmthca-dev rdmacm-utils
	ibv_devinfo
	

	#INSTALL MVAPICH
	cd $CLOUDLABDIR
	wget $MVAPICHURL
        tar -xvzf $MVAPICHVER.tar.gz

	cd $MVAPICHPATH

	./configure #--with-device=ch3:mrail --with-rdma=gen2	
	make clean
	make -j$NPROC
	COOL_DOWN
	sudo make install
	COOL_DOWN
	cd $MVAPICHBENCH
	./configure CC=/usr/local/bin/mpicc CXX=/usr/local/bin/mpicxx
}

RUN_IBBENCH() {
	#Run a MVAPICH BENCHMARK
	cd $MVAPICHBENCH
	COOL_DOWN
	sudo mpirun -np $MPIPROCS mpi/one-sided/osu_acc_latency
	COOL_DOWN
	sudo mpirun -np $MPIPROCS mpi/collective/osu_igatherv
	COOL_DOWN
	sudo mpirun -np $MPIPROCS mpi/pt2pt/osu_bw	
}


INSTALL_SCHEDSP() {
 cd $CLOUDLABDIR
 git clone https://gitlab.com/sudarsunkannan/schedsp.git
 cd schedsp
}

SETUPSSH() {
    cd $SCRIPTS
    git clone https://github.com/SudarsunKannan/cloudlabkeys
    cp $SCRIPTS/cloudlabkeys/* ~/.ssh/
    cat ~/.ssh/d_rsa.pub >> ~/.ssh/authorized_keys
}


FORMAT_DISK  #//OPTIONAL to format disk
COOL_DOWN
INSTALL_SYSTEM_LIBS
CONFIGURE_GIT
COOL_DOWN
