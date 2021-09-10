#!/bin/zsh

## 1. obtain input details from git
NAME=$(git config user.name)
if [[ -z "$NAME" ]]
then
  echo "Unable to get your name from git configuration..."
  echo "Please enter your name, followed by [ENTER]"
  read NAME
fi

EMAIL=$(git config user.email)
if [[ -z "$EMAIL" ]]
then
  echo "Unable to get your email address from git configuration..."
  echo "Please enter the email associated with your GitHub account, followed by [ENTER]"
  read EMAIL
fi
echo -e "Using name \x1b[32m$NAME\x1b[0m and email address \x1b[32m$EMAIL\x1b[0m..."

cat <<EOF
(Optional) A short comment can be included in the user name of the key
to help identify what the key is used for, e.g., signing from a specific
computer.  For no comment, just press [ENTER].
Enter a short comment (<20 characters), followed by [ENTER]...
EOF
read COMMENT
if [[ -z "$COMMENT" ]]
then
  NAME_COMMENT=""
else
  NAME_COMMENT="Name-Comment: $COMMENT"
fi

echo "Enter a passphrase, followed by [ENTER]"
read PASSPHRASE

echo -e "\n\x1b[31mNote: store the passphrase somewhere safe, in case you'll need to use it later.\x1b[0m\n"

## 2. generate the key
INPUT_TMPFILE=$(mktemp /tmp/gkgin.XXXXXX)
cat >$INPUT_TMPFILE <<EOF
  %echo Generating a basic OpenPGP key
  Key-Type: RSA
  Key-Length: 4096
  Key-Usage: sign
  Name-Real: $NAME
  $NAME_COMMENT
  Name-Email: $EMAIL
  Expire-Date: 0
  Passphrase: $PASSPHRASE
  %commit
  %echo done
EOF

OUTPUT_TMPFILE=$(mktemp /tmp/gkgout.XXXXXX)
if ! gpg --batch --generate-key $INPUT_TMPFILE 2>&1 | tee $OUTPUT_TMPFILE
then
  echo -e "\x1b[31mOoops... something went wrong!\x1b[0m"
  echo -e "\x1b[36mgpg --generate-key\x1b[0m failed."
  echo -e "Check the input file: \x1b[36m$INPUT_TMPFILE\x1b[0m..."
  echo -e "... and the output file: \x1b[36m$OUTPUT_TMPFILE\x1b[0m\n"
  echo -e "Don't forget to delete both these files after examination."
  exit
fi
if grep "key generation failed" $OUTPUT_TMPFILE > /dev/null 2>&1
then
  echo -e "\x1b[31mOoops... something went wrong!\x1b[0m"
  echo -e "\x1b[36mgpg --generate-key\x1b[0m failed."
  echo -e "Check the input file: \x1b[36m$INPUT_TMPFILE\x1b[0m..."
  echo -e "... and the output file: \x1b[36m$OUTPUT_TMPFILE\x1b[0m\n"
  echo -e "Don't forget to delete both these files after examination."
  exit
fi
rm $INPUT_TMPFILE

## 3. set the key locally
KEY=$(awk '/gpg: key / {print $3}' $OUTPUT_TMPFILE)
if [[ -z "$KEY" ]]
then
  echo -e "\x1b[31mOoops... something went wrong!\x1b[0m"
  echo -e "Can't determine the new GPG Key."
  echo -e "Check the output file: \x1b[36m$OUTPUT_TMPFILE\x1b[0m"
  exit
fi
rm $OUTPUT_TMPFILE

echo -ne "Do you wish to use this key for git commit signing on \x1b[37;1mTHIS\x1b[0m computer? [\x1b[37;1mN\x1b[0my] "
read YESNO

if [[ "$YESNO" == "Y" || "$YESNO" == "y" ]]
then
  echo "Setting the signing key in the global gitconfig file..."
  git config --global user.signingkey $KEY
  git config --global commit.gpgsign true
fi

## 4. advise user to copy key to their GitHub account
gpg --armor --export $KEY
echo -e "\nCopy your GPG key above, beginning with \x1b[32m-----BEGIN PGP PUBLIC KEY BLOCK-----\x1b[0m"
echo -e "and ending with \x1b[32m-----END PGP PUBLIC KEY BLOCK-----\x1b[0m\n"
echo "In a browser window that is logged into the GitHub account associated with"
echo -e "\x1b[32m$EMAIL\x1b[0m, go to \x1b[36mhttps://github.com/settings/keys\x1b[0m"
echo "and add the new GPG key to your account.\n"
echo "Unfortunately, GitHub only shows the email address associated with each key, so"
echo "note the KeyID and passphrase below somewhere safe, as well as its intended use,"
echo "e.g., which computer/SPIN instance it's associated with."
echo -e "-> Key ID    : \x1b[32m$KEY\x1b[0m"
echo -e "-> Passphrase: \x1b[32m$PASSPHRASE\x1b[0m"
echo -e "-> Comment   : \x1b[32m$COMMENT\x1b[0m"
