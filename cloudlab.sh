#!/bin/bash

HOMEDIR=$HOME

#Set your disk partitions
DISK=$HOME/ssd
DISK_DEVICE="/dev/sdb"
DISK_PARTITION="/dev/sdb1"
CLOUDLAB=$DISK/cloudlab

LEVELDBHOME=$CLOUDLAB/leveldb-nvm
YCSBHOME=$CLOUDLAB/leveldb-nvm/mapkeeper/ycsb/YCSB

MVAPICH="mvapich2-2.3.3"

COOL_DOWN() {
	sleep 5
}

FORMAT_DISK() {
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
    export PATH=$PATH:$CLOUDLAB/bistro/bistro/build/deps/fbthrift
    cd $CLOUDLAB/bistro/bistro/build
    sed -i "/googletest.googlecode/c\wget http://downloads.sourceforge.net/project/mxedeps/gtest-1.7.0.zip -O gtest-1.7.0.zip" $CLOUDLAB/bistro/bistro/build/build.sh
    ./build.sh Debug runtests
}

INSTALL_THRIFT(){
    cd $HOMEDIR/cloudlab/bistro/bistro
    ../bistro/build/deps_ubuntu_12.04.sh

    INSTALL_FOLLY   

    cd $HOMEDIR/cloudlab/bistro/bistro/build/deps/fbthrift/thrift
    autoreconf -ivf
    ./configure
    make -j16
    sudo make install
    cd $HOMEDIR/cloudlab/bistro/bistro/build
}

INSTALL_BISTRO(){
	cd $CLOUDLAB
	git clone https://github.com/facebook/bistro.git
	INSTALL_THRIFT
	BUILD_BISTRO
}


INSTALL_YCSB() {
    cd $CLOUDLAB
    if [ ! -d "leveldb-nvm" ]; then
        git clone https://gitlab.com/sudarsunkannan/leveldb-nvm.git
    fi
    cd $CLOUDLAB/leveldb-nvm/mapkeeper/ycsb/YCSB
    mvn clean package
}


INSTALL_CASANDARA_BINARY(){

    mkdir $CLOUDLAB/cassandra	
    echo "deb http://www.apache.org/dist/cassandra/debian 39x main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list
    echo "deb-src http://www.apache.org/dist/cassandra/debian 39x main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list

    gpg --keyserver pgp.mit.edu --recv-keys F758CE318D77295D
    gpg --export --armor F758CE318D77295D | sudo apt-key add -

    gpg --keyserver pgp.mit.edu --recv-keys 2B5C1B00
    gpg --export --armor 2B5C1B00 | sudo apt-key add -

    gpg --keyserver pgp.mit.edu --recv-keys 0353B12C
    gpg --export --armor 0353B12C | sudo apt-key add -

    sudo apt-get update
    sudo apt-get install -y --force-yes cassandra
    #RUN_YCSB_CASSANDARA
}

DOWNLOAD_CASANDARA_SOURCE(){
    mkdir $CLOUDLAB/cassandra	
    cd $CLOUDLAB/cassandra
    wget http://archive.apache.org/dist/cassandra/3.9/apache-cassandra-3.9-src.tar.gz
    tar -xvzf apache-cassandra-3.9-src.tar.gz
}

INSTALL_CASANDARA_SOURCE(){

    mkdir $CLOUDLAB/cassandra
    cd $CLOUDLAB/cassandra

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
    cd $CLOUDLAB
    wget https://cmake.org/files/v3.7/cmake-3.7.0-rc3.tar.gz
    tar zxvf cmake-3.7.0-rc3.tar.gz
    cd cmake-3.7.0*
    ./configure
    ./bootstrap
    make -j16
    make install
}

INSTALL_SYSTEM_LIBS(){
	sudo apt-get install -y git
	git config --global user.name "sudarsun"
	git config --global user.email "sudarsun.kannan@gmail.com"
	#git commit --amend --reset-author
	sudo apt-get install kernel-package
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
	INSTALL_JAVA
}

#IB libs
INSTALL_IB_LIBS() {
	sudo apt-get install libibumad-dev libibumad3
	sudo apt-get install libibverbs-dev
	sudo apt-get install gfortran

	#INSTALL MVAPICH
	cd $CLOUDLAB
	wget http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/$MVAPICHVER.tar.gz
        tar -xvzf $MVAPICHVER.tar.gz
	cd $MVAPICHVER	
	./configure --with-device=ch3:mrail --with-rdma=gen2	
	make clean
	NPROC=`nproc`
	make -j$NPROC
	COOL_DOWN
	sudo make install
	COOL_DOWN

	#Run a MVAPICH BENCHMARK
	cd $MVAPICHVER/osu_benchmarks
	./configure CC=/usr/local/bin/mpicc CXX=/usr/local/bin/mpicxx
	COOL_DOWN
	sudo mpirun -np 2 mpi/one-sided/osu_acc_latency
}


INSTALL_SCHEDSP() {
 cd $CLOUDLAB
 git clone https://gitlab.com/sudarsunkannan/schedsp.git
 cd schedsp
}



FORMAT_DISK
COOL_DOWN
INSTALL_SYSTEM_LIBS
COOL_DOWN
INSTALL_IB_LIBS


#Install ycsb and casandara
#INSTALL_YCSB
#RUN_YCSB_CASSANDARA
#INSTALL_SCHEDSP
#INSTALL_CMAKE
#INSTALL_YCSB

