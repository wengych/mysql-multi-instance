#!/bin/bash -e

echo "Input server ip:"
read SERVER_IP

echo "Input new mysql instance name:"
read INSTANCE_NAME

MYSQL_CONF="/etc/"${INSTANCE_NAME}

if [ -e ${MYSQL_CONF} ]; then
  echo "mysql instance existed. quit!"
  exit 1
fi

echo "Input mysql listen port:"
read MYSQLD_LISTEN_PORT

echo "Input mysql data file path(enter as /var/lib/${INSTANCE_NAME}):"
read MYSQL_DATA_DIR
if [ -z ${MYSQL_DATA_DIR} ]; then
  MYSQL_DATA_DIR="/var/lib/"${INSTANCE_NAME}
fi

#INSTANCE_NAME="mysql1"
#MYSQLD_LISTEN_PORT=""
#MYSQL_DATA_DIR="/var/lib/"${INSTANCE_NAME}
MYSQLD_SOCK_FILE="/var/run/mysqld/${INSTANCE_NAME}.sock"
MYSQLD_PID_FILE="/var/run/mysqld/${INSTANCE_NAME}.pid"

DEBIAN_CNF="${MYSQL_CONF}/debian.cnf"
DEBIAN_SYS_MAINT_PASS=`perl -e 'print map{("a".."z","A".."Z",0..9)[int(rand(62))]}(1..16)'`

mkdir ${MYSQL_DATA_DIR}
chown -R mysql.mysql ${MYSQL_DATA_DIR}

# Generate mysql config files
cp -R etc/mysql-multi ${MYSQL_CONF}
sed -i "s@server_ip_address@"$SERVER_IP"@g"           ${MYSQL_CONF}/my.cnf
sed -i "s@mysql_listen_port@"$MYSQLD_LISTEN_PORT"@g"  ${MYSQL_CONF}/my.cnf
sed -i "s@mysqld_sock_file@"$MYSQLD_SOCK_FILE"@g"     ${MYSQL_CONF}/my.cnf
sed -i "s@mysqld_pid_file@"$MYSQLD_PID_FILE"@g"       ${MYSQL_CONF}/my.cnf
sed -i "s@mysql_data_dir@"$MYSQL_DATA_DIR"@g"         ${MYSQL_CONF}/my.cnf
sed -i "s@mysql_instance_name@"$INSTANCE_NAME"@g"     ${MYSQL_CONF}/debian-start

echo "# Automatically generated for Debian scripts. DO NOT TOUCH!" > ${DEBIAN_CNF}
echo "[client]"                            >> ${DEBIAN_CNF}
echo "host     = localhost"                >> ${DEBIAN_CNF}
echo "user     = debian-sys-maint"         >> ${DEBIAN_CNF}
echo "password = ${DEBIAN_SYS_MAINT_PASS}" >> ${DEBIAN_CNF}
echo "socket   = ${MYSQLD_SOCK_FILE}"      >> ${DEBIAN_CNF}
echo "[mysql_upgrade]"                     >> ${DEBIAN_CNF}
echo "host     = localhost"                >> ${DEBIAN_CNF}
echo "user     = debian-sys-maint"         >> ${DEBIAN_CNF}
echo "password = ${DEBIAN_SYS_MAINT_PASS}" >> ${DEBIAN_CNF}
echo "socket   = ${MYSQLD_SOCK_FILE}"      >> ${DEBIAN_CNF}
echo "basedir  = /usr"                     >> ${DEBIAN_CNF}

mysql_install_db --user=mysql --datadir=${MYSQL_DATA_DIR}

if [ `dirname ${MYSQL_DATA_DIR}` = "/mnt/ramdisk" ]; then
  /etc/init.d/${INSTANCE_NAME} stop
  cp -R ${MYSQL_DATA_DIR} /root
  /etc/init.d/${INSTANCE_NAME} start
fi

# Generate mysql init.d script
cp etc/init.d/mysql-multi /etc/init.d/${INSTANCE_NAME}
sed -i "s@mysql_instance_config_path@"$MYSQL_CONF"@g" /etc/init.d/${INSTANCE_NAME}
sed -i "s@mysql_data_dir@"$MYSQL_DATA_DIR"@g"         /etc/init.d/${INSTANCE_NAME}
sed -i "s@mysql_instance_name@"$INSTANCE_NAME"@g"     /etc/init.d/${INSTANCE_NAME}

# Update debian-sys-maint user in new database
/etc/init.d/${INSTANCE_NAME} start

mysql -S ${MYSQLD_SOCK_FILE} -e "create user 'debian-sys-maint' identified by '${DEBIAN_SYS_MAINT_PASS}'"
mysql -S ${MYSQLD_SOCK_FILE} -e "grant all privileges on *.* to 'debian-sys-maint'@'%'"

mysql -S ${MYSQLD_SOCK_FILE} -e "create user 'admin' identified by 'admin'"
mysql -S ${MYSQLD_SOCK_FILE} -e "grant all privileges on *.* to 'admin'@'%'"

