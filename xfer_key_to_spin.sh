#!/bin/zsh

##
# 1. select key to transfer, if more than one
##
TMP_LIST_KEYS_OUTPUT=$(mktemp /tmp/gpgkeys.XXXXXX)
gpg --list-keys --keyid-format=long 2>&1 | tee $TMP_LIST_KEYS_OUTPUT

KEY_COUNT=$(grep '^pub' $TMP_LIST_KEYS_OUTPUT | wc -l | awk '{print $1}')
if [[ $KEY_COUNT == 0 ]]
then
  echo "No GPG keys found to transfer... exiting"
  rm $TMP_LIST_KEYS_OUTPUT
  exit
fi

if [[ $KEY_COUNT > 1 ]]
then
  # need to pick the appropriate key to transfer
  echo "$KEY_COUNT keys found..."
  grep '^pub' $TMP_LIST_KEYS_OUTPUT | awk -F'[ /]+' '{print $3}' | ruby -e '$stdin.read.split("\n").each_with_index { |k,i| puts "#{i+1}. #{k}" }'
  echo -n "Choose key to copy? (1-$KEY_COUNT) "
  read KEY_NUM
  if [[ -z $KEY_NUM || $KEY_NUM < 1 || $KEY_NUM > $KEY_COUNT ]]
  then
    echo "No key chosen... exiting"
    rm $TMP_LIST_KEYS_OUTPUT
    exit
  fi
  KEY_ID=$(grep '^pub' $TMP_LIST_KEYS_OUTPUT | awk -F'[ /]+' '{print $3}' | ruby -e 'puts $stdin.read.split("\n")[ARGV[0].to_i-1]' $KEY_NUM)
else
  # have only one key
  KEY_ID=$(grep '^pub' $TMP_LIST_KEYS_OUTPUT | awk -F'[ /]+' '{print $3}')
fi
rm $TMP_LIST_KEYS_OUTPUT

echo "\n$KEY_ID selected"

##
# 2. select spin instance for destination
##
TMP_SPIN_LIST=$(mktemp /tmp/spinlist.XXXXXX)
# capture just the needed details
spin list -o json | ruby -e 'require "json"; o = {}; JSON.parse($stdin.read)["Workspaces"].each { |w| w["Services"].each { |s, d| o[d["Name"]] = d["FQDN"] } }; puts o.to_json' > $TMP_SPIN_LIST
SPIN_LIST_COUNT=$(cat $TMP_SPIN_LIST | ruby -e 'require "json"; puts JSON.parse($stdin.read).keys.count')
if [[ $SPIN_LIST_COUNT == 0 ]]
then
  echo -e "No SPIN services/hostnames for copying key... use \x1b[36mspin create <service>\x1b[0m to create a workspace"
  rm $TMP_SPIN_LIST
  exit
fi

if [[ $SPIN_LIST_COUNT == 1 ]]
then
  OPTION=1
else
  # print the options
  cat $TMP_SPIN_LIST | ruby -e 'require "json"; i=0; JSON.parse($stdin.read).each { |s, h| puts "#{i+=1}. Service: \"#{s}\", SPIN host = \"#{h}\"" }'
  echo "Choose destination service (1-$SPIN_LIST_COUNT)"
  read OPTION
fi
DEST=$(cat $TMP_SPIN_LIST | ruby -e 'require "json"; l=[]; JSON.parse($stdin.read).each { |_, h| l << h }; puts l[ARGV[0].to_i-1]' $OPTION)
rm $TMP_SPIN_LIST

##
# 3. create public key file to transfer
##
TMP_PUB_KEY_FILE=$(mktemp /tmp/gpgkey.XXXXXX)
gpg --armor --export $KEY_ID > $TMP_PUB_KEY_FILE

##
# 4. generate spin batch command file (for after transfer)
##
TMP_SPIN_CMDS=$(mktemp /tmp/spincmds.XXXXXX)
cat > $TMP_SPIN_CMDS <<EOF
#!/bin/zsh
cd ~
if ! gpg --import $(basename $TMP_PUB_KEY_FILE)
then
  echo -e "\x1b[31mOoops... something went wrong!\x1b[0m"
  echo -e "\x1b[36mgpg --import\x1b[0m failed."
  rm $(basename $TMP_PUB_KEY_FILE)
  exit
fi
rm $(basename $TMP_PUB_KEY_FILE)

if ! git config --global user.signingkey $KEY_ID
then
  echo -e "\x1b[31mOoops... something went wrong!\x1b[0m"
  echo -e "\x1b[36mConfig of user.signingkey\x1b[0m failed."
  exit
fi

if ! git config --global commit.gpgsign true
then
  echo -e "\x1b[31mOoops... something went wrong!\x1b[0m"
  echo -e "\x1b[36mConfig of commit.gpgsign\x1b[0m failed."
  exit
fi
echo "Successfully configured public key for git"
rm $(basename $TMP_SPIN_CMDS)
EOF
chmod +x $TMP_SPIN_CMDS

##
# 5. generate sftp batch command file
##
TMP_SFTP_CMDS=$(mktemp /tmp/sftpcmds.XXXXXX)
cat > $TMP_SFTP_CMDS <<EOF
lcd /tmp
put $(basename $TMP_PUB_KEY_FILE)
put $(basename $TMP_SPIN_CMDS)
EOF

##
# 6. transfer key file and spin command file to spin instance
##
if ! sftp -b $TMP_SFTP_CMDS $DEST
then
  echo -e "\x1b[31mOoops... something went wrong!\x1b[0m"
  echo -e "\x1b[36mSecure ftp\x1b[0m failed."
  rm $TMP_PUB_KEY_FILE $TMP_SFTP_CMDS $TMP_SPIN_CMDS
  exit
fi

## 7. execute spin command file
if ! spin ssh $DEST -- "cd ~; ./$(basename $TMP_SPIN_CMDS)"
then
  echo -e "\x1b[31mOoops... something went wrong!\x1b[0m"
  echo -e "\x1b[36mRemote script $(basename $TMP_SPIN_CMDS)\x1b[0m failed."
fi

## 8. delete temporary files
rm $TMP_PUB_KEY_FILE $TMP_SFTP_CMDS $TMP_SPIN_CMDS
