	FROM debian:stretch


RUN apt-get update  &&\
	apt-get install -y wget gnupg2 apt-utils
	
	
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" >> /etc/apt/sources.list.d/pgdg.list &&\
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - &&\
	apt-cache search postgresql-9.6 &&\
	apt-get update &&\
	apt-get install -y postgresql-9.6  	

ENV PATH $PATH:/usr/lib/postgresql/9.6/bin
ENV PG_DATA /var/lib/postgresql/9.6/application

# ADD debezium

ENV PLUGIN_VERSION=v0.6.1
ENV WAL2JSON_COMMIT_ID=645ab69aae268a81c900671b5dfab7029384e9ff

# Install the packages which will be required to get everything to compile
RUN apt-get update \ 
    && apt-get install -f -y --no-install-recommends \
        software-properties-common \
        build-essential \
        pkg-config \ 
        git \
        postgresql-server-dev-9.6 \
        libproj-dev \
    && apt-get clean && apt-get update && apt-get install -f -y --no-install-recommends \            
        liblwgeom-dev \              
    && add-apt-repository "deb http://ftp.debian.org/debian testing main contrib" \ 
    && apt-get update && apt-get install -f -y --no-install-recommends \
        libprotobuf-c-dev=1.2.* \
    && rm -rf /var/lib/apt/lists/*             
 
# Compile the plugin from sources and install it
RUN git clone https://github.com/debezium/postgres-decoderbufs -b $PLUGIN_VERSION --single-branch \
    && cd /postgres-decoderbufs \ 
    && make && make install \
    && cd / \ 
    && rm -rf postgres-decoderbufs

RUN git clone https://github.com/eulerto/wal2json -b master --single-branch \
    && cd /wal2json \
    && git checkout $WAL2JSON_COMMIT_ID \
    && make && make install \
    && cd / \
    && rm -rf wal2json

RUN cat /etc/postgresql/9.6/main/pg_hba.conf

USER postgres
RUN /usr/lib/postgresql/9.6/bin/initdb -D $PG_DATA -E UTF8

COPY config/postgresql.conf $PG_DATA/application/postgresql.conf
COPY config/pg_hba.conf $PG_DATA/application/pg_hba.conf

RUN ls -la  $PG_DATA/application

CMD /usr/lib/postgresql/9.6/bin/postgres  -D $PG_DATA