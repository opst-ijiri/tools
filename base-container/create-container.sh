#!/bin/sh

HISTORY=2 ;

CUR_DIRNAME=`date +"%Y%m%d_%H%M%S"`;

# 使い方
###########################################
function help() {
  echo "create-container.sh -n <container name> -v <container version>";
  exit 1;
}

# 引数の解析
###########################################
CONTAINER_NAME="";
CONTAINER_VERSION="";

while [ $# -ne 0 ]
do
  if [ "$1x" == "-nx" ]; then
    shift;
    CONTAINER_NAME="$1";
    shift;
  elif [ "$1x" == "-vx" ]; then
    shift;
    CONTAINER_VERSION="$1";
    shift;
  fi
done

if ( [ "${CONTAINER_NAME}x" == "x" ] && [ "${CONTAINER_VERSION}x" == "x" ] ); then
  source ./container.prop
fi

if [ "${CONTAINER_NAME}x" == "x" ]; then
  help;
fi

if [ "${CONTAINER_VERSION}x" == "x" ]; then
  help;
fi

if [ ! -d ./dest ]; then
  mkdir -p ./dest
fi
cd ./dest

# cloneした古いツールのディレクトリを掃除
###########################################
COUNT=0;
for OLD_DIRNAME in `ls -1t`
do
  if [ $COUNT -ge ${HISTORY} ]; then
    rm -Rf ${OLD_DIRNAME};
  else
    COUNT=$(expr ${COUNT} + 1);
  fi
done

for file in /etc/{redhat,system}-release
do
  if [ -r "$file" ]; then
    OS_VERSION="$(sed 's/^[^0-9\]*\([0-9.]\+\).*$/\1/' "$file")"
    break;
  fi
done


git clone https://github.com/docker/docker.git ${CUR_DIRNAME}
cd ${CUR_DIRNAME}/

RUN_SCRIPT="contrib/mkimage-yum.sh";

mv  ${RUN_SCRIPT}  ${RUN_SCRIPT}.org
cat  ${RUN_SCRIPT}.org | sed -e 's#^HOSTNAME=localhost.localdomain$#HOSTNAME=localhost.localdomain\nNOZEROCONF=yes#'| sed -e 's#^rm -rf "\$target"$##'|egrep -v -e "rm -rf .+locale"|egrep -v -e "rm -rf .+man"|egrep -v -e "rm -rf .+i18n" >> ${RUN_SCRIPT}

cat <<__EOF__ >> ${RUN_SCRIPT}
/bin/rm -f "\$target"/etc/pam_ldap.conf
ln -sf /etc/openldap/ldap.conf "\$target"/etc/pam_ldap.conf

#################
# SSHD Settinng #
#################
mv "\$target"/etc/ssh/sshd_config "\$target"/etc/ssh/sshd_config.org

sed -E 's/^HostKey/# HostKey/g' "\$target"/etc/ssh/sshd_config.org > "\$target"/etc/ssh/sshd_config
echo 'AuthorizedKeysCommand /usr/libexec/openssh/ssh-ldap-wrapper' >> "\$target"/etc/ssh/sshd_config
echo 'AuthorizedKeysCommandUser root' >> "\$target"/etc/ssh/sshd_config

/bin/rm -f "\$target"/etc/ssh/sshd_config.org

#################
# nsswitch.conf #
#################
mv "\$target"/etc/nsswitch.conf "\$target"/etc/nsswitch.conf.org

cat  "\$target"/etc/nsswitch.conf.org |\
sed -e 's#passwd:     files sss#passwd:     files sss ldap#' \
    -e 's#shadow:     files sss#shadow:     files sss ldap#' \
    -e 's#group:      files sss#group:      files sss ldap#' \
    -e 's#netgroup:   nisplus sss#netgroup:   files sss ldap#' \
    -e 's#automount:  files nisplus#automount:  files ldap#' \
    > "\$target"/etc/nsswitch.conf

/bin/rm -f "\$target"/etc/nsswitch.conf.org

####################
# pam  system-auth #
####################
mv "\$target"/etc/pam.d/system-auth "\$target"/etc/pam.d/system-auth.org

cat "\$target"/etc/pam.d/system-auth.org |\
sed -e 's#auth        sufficient    pam_unix.so try_first_pass nullok#auth        sufficient    pam_unix.so try_first_pass nullok\nauth        requisite     pam_succeed_if.so uid >= 500 quiet_success\nauth        sufficient    pam_ldap.so use_first_pass#' \
    -e 's#account     required      pam_unix.so#account     required      pam_unix.so broken_shadow\naccount     sufficient    pam_localuser.so\naccount     sufficient    pam_succeed_if.so uid < 500 quiet\naccount     [default=bad success=ok user_unknown=ignore] pam_ldap.so\naccount     required      pam_permit.so#' \
    -e 's#password    sufficient    pam_unix.so try_first_pass use_authtok nullok sha512 shadow#password    sufficient    pam_unix.so md5 shadow nullok try_first_pass use_authtok\npassword    sufficient    pam_ldap.so use_authtok#' \
    -e 's#session     required      pam_limits.so#session     required      pam_limits.so\n-session     optional      pam_systemd.so\nsession     optional      pam_mkhomedir.so umask=0077#' \
    -e 's#session     required      pam_unix.so#session     required      pam_unix.so\nsession     optional      pam_ldap.so#' \
    > "\$target"/etc/pam.d/system-auth

/bin/rm -f "\$target"/etc/pam.d/system-auth.org

######################
# pam  password-auth #
######################
mv "\$target"/etc/pam.d/password-auth "\$target"/etc/pam.d/password-auth.org

cat "\$target"/etc/pam.d/password-auth.org |\
sed -e 's#auth        sufficient    pam_unix.so try_first_pass nullok#auth        sufficient    pam_unix.so try_first_pass nullok\nauth        requisite     pam_succeed_if.so uid >= 500 quiet_success\nauth        sufficient    pam_ldap.so use_first_pass#' \
    -e 's#account     required      pam_unix.so#account     required      pam_unix.so broken_shadow\naccount     sufficient    pam_localuser.so\naccount     sufficient    pam_succeed_if.so uid < 500 quiet\naccount     [default=bad success=ok user_unknown=ignore] pam_ldap.so\naccount     required      pam_permit.so#' \
    -e 's#password    sufficient    pam_unix.so try_first_pass use_authtok nullok sha512 shadow#password    sufficient    pam_unix.so md5 shadow nullok try_first_pass use_authtok\npassword    sufficient    pam_ldap.so use_authtok#' \
    -e 's#session     required      pam_limits.so#session     required      pam_limits.so\n-session     optional      pam_systemd.so\nsession     optional      pam_mkhomedir.so umask=0077#' \
    -e 's#session     required      pam_unix.so#session     required      pam_unix.so\nsession     optional      pam_ldap.so#' \
    > "\$target"/etc/pam.d/password-auth

/bin/rm -f "\$target"/etc/pam.d/password-auth.org

#########################
# pam  fingerprint-auth #
#########################
mv "\$target"/etc/pam.d/fingerprint-auth "\$target"/etc/pam.d/fingerprint-auth.org

cat "\$target"/etc/pam.d/fingerprint-auth.org |\
sed -e 's#account     required      pam_unix.so#account     required      pam_unix.so broken_shadow#' \
    -e 's#account     required      pam_permit.so#account     [default=bad success=ok user_unknown=ignore] pam_ldap.so\naccount     required      pam_permit.so#' \
    -e 's#session     required      pam_limits.so#session     required      pam_limits.so\n-session     optional      pam_systemd.so\nsession     optional      pam_mkhomedir.so umask=0077#' \
    -e 's#session     required      pam_unix.so#session     required      pam_unix.so\nsession     optional      pam_ldap.so#' \
    > "\$target"/etc/pam.d/fingerprint-auth

/bin/rm -f "\$target"/etc/pam.d/fingerprint-auth.org

ln -sf /etc/openldap/ldap.conf "\$target"/etc/ssh/ldap.conf
mkdir "\$target"/etc/openldap/cacerts

tar --numeric-owner -c -C "\$target" -f ${CONTAINER_NAME}_${CONTAINER_VERSION}.tar .

docker rmi ${CONTAINER_NAME}_${CONTAINER_VERSION}:${OS_VERSION}

/bin/rm -rf "\$target"
__EOF__

/bin/sh -x ${RUN_SCRIPT} -y /etc/yum.conf -p "openssh-server sudo openldap-clients openssh-ldap nss-pam-ldapd pam_ldap nscd" ${CONTAINER_NAME}_${CONTAINER_VERSION}

if [ -e ../${CONTAINER_NAME}_${CONTAINER_VERSION}.tar ]; then
  /bin/rm -f ${CONTAINER_NAME}_${CONTAINER_VERSION}.tar
fi
mv ${CONTAINER_NAME}_${CONTAINER_VERSION}.tar ../
