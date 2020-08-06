# mlcc -i RHEL7.7,Numpy,TensorFlow
# mlcc version: 20181224a: Nov 12 2019

# Install UBI 7.7 backed by lower priority RHEL 7 repos

FROM nvidia/cuda:10.1-cudnn7-runtime-ubi7

RUN set -vx \
\
&& yum-config-manager --enable \
    rhel-7-server-rpms \
    rhel-7-server-extras-rpms \
    rhel-7-server-optional-rpms \
\
&& sed -i '/enabled = 1/ a priority =  1' /etc/yum.repos.d/ubi.repo \
&& sed -i '/enabled = 1/ a priority = 99' /etc/yum.repos.d/redhat.repo \
\
&& yum -y -v install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm" \
\
&& yum -y update \
&& yum clean all


# Install Basic OS Tools

RUN set -vx \
\
&& echo -e '\
set -vx \n\
for (( TRY=1; TRY<=3; TRY++ )); do \n\
    /bin/ls -alFR /usr/lib/.build-id \n\
    /bin/rm -rf /usr/lib/.build-id \n\
    yum -y -v install $@ \n\
    result=$? \n\
    for PKG in $@ ; do \n\
        yum list installed | grep "^$PKG" \n\
        (( result += $? )) \n\
    done \n\
    if (( $result == 0 )); then \n\
        yum clean all \n\
        exit 0 \n\
    else \n\
        echo "Missing packages: ${result} of $@" \n\
    fi \n\
    sleep 10 \n\
done \n\
exit 1 \n' \
> /tmp/yum_install.sh \
\
&& echo -e '\
set -vx \n\
CACHE_DIR="/tmp/download_cache_dir" \n\
for FILE in $@ ; do \n\
    CACHED_FILE="$CACHE_DIR/`basename $FILE`" \n\
    if [ -r "$CACHED_FILE" ]; then \n\
        cp $CACHED_FILE . \n\
    else \n\
        wget $FILE \n\
        if [ -d "$CACHE_DIR" ]; then \n\
            cp `basename $FILE` $CACHED_FILE \n\
        fi \n\
    fi \n\
done \n' \
> /tmp/cached_wget.sh \
\
&& echo -e '\
cd /tmp \n\
for SCRIPT in $@ ; do \n\
    wget -q $SCRIPT -O `basename $SCRIPT` \n\
    /bin/bash `basename $SCRIPT` \n\
done \n' \
> /tmp/run_remote_bash_script.sh \
\
&& chmod +x /tmp/yum_install.sh /tmp/cached_wget.sh /tmp/run_remote_bash_script.sh \
\
&& cd /usr/local \
&& /bin/rm -rf lib64 \
&& ln -s lib lib64 \
\
&& /tmp/yum_install.sh \
    binutils \
    bzip2 \
    findutils \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    git \
    gzip \
    make \
    openssl-devel \
    patch \
    pciutils \
    unzip \
    vim-enhanced \
    wget \
    xz \
    zip \
&& yum clean all


# Try to use Python3.8+
# Install Python v3.8.3, if no python3 already present


RUN set -vx \
\
&& yum -y -v install libffi-devel \
&& if whereis python3 | grep -q "python3.." ; then \
\
    if yum info python38-devel > /dev/null 2>&1; then \
        /tmp/yum_install.sh python38 python38-devel python38-pip python38-setuptools python38-wheel; \
    else \
        if yum info python3-devel > /dev/null 2>&1; then \
            PYTHON3_DEVEL="python3-devel"; \
        else \
            PYTHON3_DEVEL="python3[0-9]-devel"; \
        fi; \
        /tmp/yum_install.sh python3 python3-pip ${PYTHON3_DEVEL} python3-setuptools python3-wheel; \
    fi; \
\
    ln -s /usr/bin/python3 /usr/local/bin/python3; \
    ln -s /usr/bin/pip3 /usr/local/bin/pip3; \
    for d in /usr/lib/python3*; do PYLIBDIR="$d"; echo 'PYLIBDIR: ' $PYLIBDIR; done; \
    ln -s $PYLIBDIR /usr/local/lib/`basename $PYLIBDIR`; \
    for d in /usr/include/python3*; do PYINCDIR="$d"; echo 'PYINCDIR: ' $PYINCDIR; done; \
    ln -s $PYINCDIR /usr/local/include/`basename $PYINCDIR`; \
\
else \
\
    /tmp/yum_install.sh \
        libtiff-devel \
        libjpeg-devel \
        openjpeg2-devel \
        freetype-devel \
        lcms2-devel \
        libwebp-devel \
        tcl-devel \
        tk-devel \
        harfbuzz-devel \
        fribidi-devel \
        libraqm-devel \
        libimagequant-devel \
        libxcb-devel \
        bzip2-devel \
        expat-devel \
        gdbm-devel \
        libdb4-devel \
        ncurses-devel \
        openssl-devel \
        readline-devel \
        sqlite-devel \
        tk-devel \
        xz-devel \
        zlib-devel; \
    \
    cd /tmp; \
    /tmp/cached_wget.sh "https://www.python.org/ftp/python/3.8.3/Python-3.8.3.tar.xz"; \
    tar -xf Python*.xz; \
    /bin/rm Python*.xz; \
    cd /tmp/Python*; \
    ./configure \
        --enable-optimizations \
        --enable-shared \
        --prefix=/usr/local \
        --with-ensurepip=install \
        LDFLAGS="-Wl,-rpath /usr/local/lib"; \
    make -j`getconf _NPROCESSORS_ONLN` install; \
    \
    cd /tmp; \
    /bin/rm -r /tmp/Python*; \
\
fi \
\
&& cd /usr/local/include \
&& PYTHON_INC_DIR_NAME=`ls -d ./python*` \
&& ALT_PYTHON_INC_DIR_NAME=${PYTHON_INC_DIR_NAME%m} \
&& if [ "$ALT_PYTHON_INC_DIR_NAME" != "$PYTHON_INC_DIR_NAME" ]; then \
    ln -s "$PYTHON_INC_DIR_NAME" "$ALT_PYTHON_INC_DIR_NAME"; \
fi \
\
&& /usr/local/bin/pip3 -v install --upgrade \
    pip \
    setuptools \
\
&& if python --version > /dev/null 2>&1; then \
    whereis python; \
    python --version; \
else \
    cd /usr/bin; \
    ln -s python3 python; \
    cd /usr/local/bin; \
    ln -s python3 python; \
fi \
\
&& yum clean all \
&& whereis python3 \
&& python3 --version \
&& pip3 --version \
&& /bin/ls -RFCa /usr/local/include/python*



# Install CMake v3.17.2

RUN set -vx \
\
&& cd /tmp \
&& /tmp/cached_wget.sh "https://cmake.org/files/v3.17/cmake-3.17.2.tar.gz" \
&& tar -xf cmake*.gz \
&& /bin/rm cmake*.gz \
&& cd /tmp/cmake* \
&& ./bootstrap \
&& make -j`getconf _NPROCESSORS_ONLN` install \
&& cd /tmp \
&& /bin/rm -rf /tmp/cmake* \
&& cmake --version 

RUN date; df -h

# Install Numpy

RUN set -vx \
\
&& /usr/local/bin/pip3 -v install \
    numpy \
\
&& /usr/local/bin/python3 -c 'import numpy'


RUN date; df -h

### Install necessary modules
RUN set -vx \
 && pip install --upgrade pip \
 && pip install ez_setup==0.9 \
        absl-py==0.7.1 \
        pillow==6.0.0 \
        opencv-python-headless \
        wheel


# install gflags
# -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON -DBUILD_gflags_LIB=ON .. \
RUN git clone -b v2.2.1 https://github.com/gflags/gflags.git \
 && cd gflags \
 && mkdir build && cd build \
 && cmake -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON -DBUILD_gflags_LIB=ON .. \
 && make -j \
 && make install \
 && cd /tmp && rm -rf gflags

# install glog
RUN git clone -b v0.3.5 https://github.com/google/glog.git \
 && cd glog \
 && cmake -H. -Bbuild -G "Unix Makefiles" -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON \
 && cmake --build build \
 && cmake --build build --target install \
 && cd /tmp && rm -rf glog

WORKDIR /tmp
RUN wget https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh \
 && chmod +x wait-for-it.sh \
 && mv wait-for-it.sh /usr/local/bin/

RUN git clone -b v1.0.6 https://github.com/dcdillon/cpuaff \
 && /tmp/yum_install.sh automake \
 && cd cpuaff \
 && ls -lF \
 && ./bootstrap.sh \
 && ./configure \
 && make \
 && make install \
 && cd ../ \
 &&  rm -rf cpuaff \
 && yum clean all

RUN git clone -b v1.4.1 https://github.com/google/benchmark.git \
 && cd benchmark \
 && git clone -b release-1.8.0 https://github.com/google/googletest.git \
 && mkdir build && cd build \
 && cmake .. -DCMAKE_BUILD_TYPE=RELEASE \
 && make -j && make install \
 && cd /tmp && rm -rf benchmark

RUN git clone https://github.com/jupp0r/prometheus-cpp.git \
 && cd prometheus-cpp \
 && git checkout -b yais e7709f7e3b71bc5b1ac147971c87f2f0ae9ea358 \
 && git submodule update --init --recursive \
 && mkdir build && cd build \
 && cmake -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE .. \
 && make -j \
 && make install

RUN wget https://dl.influxdata.com/telegraf/releases/telegraf-1.7.1-static_linux_amd64.tar.gz \
 && tar xzf telegraf-1.7.1-static_linux_amd64.tar.gz \
 && mv telegraf/telegraf /usr/local/bin \
 && rm -rf telegraf-1.7.1-static_linux_amd64.tar.gz telegraf

RUN git clone https://github.com/cameron314/concurrentqueue.git \
 && cd concurrentqueue \
 && git checkout 8f65a87 \
 && mkdir -p /usr/local/include/moodycamel \
 && cp *.h /usr/local/include/moodycamel/

RUN git clone https://github.com/bloomen/transwarp.git \
 && cd transwarp \
 && git checkout 1.8.0 \
 && mkdir -p /usr/local/include/transwarp \
 && cp src/transwarp.h /usr/local/include/transwarp/transwarp.h \
 && cd .. && rm -rf transwarp

# install flatbuffers
RUN git clone -b v1.10.0 https://github.com/google/flatbuffers.git \
 && cd flatbuffers \
 && mkdir build2 && cd build2 \
 && cmake -DCMAKE_BUILD_TYPE=Release .. \
 && make -j$(nproc) install \
 && rm -rf /flatbuffers

ENV BAZEL_VERSION="0.21.0"

RUN wget https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh \
 && chmod +x bazel-$BAZEL_VERSION-installer-linux-x86_64.sh \
 && ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh \
 && rm -f bazel-$BAZEL_VERSION-installer-linux-x86_64.sh

# Install protobuf - needed for onnx below
RUN git clone https://github.com/google/protobuf.git \
 && cd protobuf \
 && ./autogen.sh \
 && ./configure \
 && make

# Install dependencies of TensorRT-Laboratory
RUN set -vx \
 && pip install --upgrade pip \
 && pip install click==6.7 \
				Jinja2==2.10 \
				MarkupSafe==1.1.0 \
				grpcio==1.16.1 \
 				matplotlib==3.0.2 \
				onnx==1.3.0 \
				jupyter-client==5.2.4 \
				jupyter-core==4.4.0 \
				jupyterlab==0.35.4 \
				jupyterlab-server==0.2.0 \
				wurlitzer==1.0.2 \
				pytest==4.6.2

# Install TensorFlow, needed by SSDMobileNet benchmark
# Install CPU version since we don't actually need to run TensorFlow.
RUN set -vx \
 && pip install --upgrade pip \
 && pip install tensorflow==1.13.1

# Install pytorch and torchvision, needed by SSDResNet34 benchmark
RUN set -vx \
 && pip install --upgrade pip \
 && pip install torch==1.1.0 \
				torchvision==0.3.0 \
				pycuda==2019.1 \
				Cython==0.29.10 \
				pycocotools==2.0.0

# Install sacrebleu, needed by GNMT benchmark
RUN set -vx \
 && pip install --upgrade pip \
 && pip install sacrebleu==1.3.3

# Install CUB, needed by GNMT benchmark
RUN wget https://github.com/NVlabs/cub/archive/1.8.0.zip -O cub-1.8.0.zip \
 && unzip cub-1.8.0.zip \
 && mv cub-1.8.0/cub /usr/include/x86_64-linux-gnu/ \
 && rm -rf cub-1.8.0.zip cub-1.8.0

# Install TensorRT Python bindings
RUN bash /opt/tensorrt/python/python_setup.sh

#install libjemalloc2
#RUN echo 'deb http://archive.ubuntu.com/ubuntu disco main restricted universe multiverse' | tee -a /etc/apt/sources.list.d/disco.list \
 # && echo 'Package: *\nPin: release a=disco\nPin-Priority: -10\n' | tee -a /etc/apt/preferences.d/disco.pref \
  #&& apt-get update \
  #&& apt-get install --no-install-recommends -t disco -y libjemalloc2 libtcmalloc-minimal4

# Install TRT-Lab, which requires g++-5
RUN git clone https://github.com/NVIDIA/tensorrt-laboratory.git \
 && cd tensorrt-laboratory \
 && git checkout e1eed23d1966fdbe8b2c9d2f5e8e1da5b17b94f8 \
 && mkdir -p build \
 && cd build \
 && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_NVRPC=OFF -DENABLE_TESTING=OFF .. \
 && make -j \
 && make install \
 && cd ../.. \
 && rm -rf tensorrt-laboratory

# Instsall SimpleJSON
RUN git clone https://github.com/MJPA/SimpleJSON.git \
 && cd SimpleJSON \
 && mkdir build \
 && g++ -c -Wall src/JSON.cpp -o build/JSON.o \
 && g++ -c -Wall src/JSONValue.cpp -o build/JSONValue.o \
 && ar rcs /usr/lib/x86_64-linux-gnu/libSimpleJSON.a build/JSON.o build/JSONValue.o \
 && cp src/JSON.h /usr/include/x86_64-linux-gnu \
 && cp src/JSONValue.h /usr/include/x86_64-linux-gnu \
 && cd .. \
 && rm -rf SimpleJSON

# Copy repo to work directory
COPY . /work

# Build binaries so that the image can be used out-of-the-box
RUN cd /work

WORKDIR /work

