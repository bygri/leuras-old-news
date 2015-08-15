#!/bin/sh
# $1 is the Trove ID. $2 is the letter.
DATE=`date +%Y-%m-%d`
sips -s format jpeg -s formatOptions normal *.png --out $1$2.jpg
open $1$2.jpg
cat > $1$2.txt <<EOL
Title:
Key: ${1}${2}
Category:
Publication: KatoombaTimes
Page:
PubDate: 1889-
DateUpdated: ${DATE}
TroveID: ${1}
Precis:

#
EOL
choc $1$2.txt
read -p "Press [Enter] when editing is complete, or Ctrl-C to cancel."
mv $1$2.jpg ../article-img
mv $1$2.txt ../articles
rm *.png
