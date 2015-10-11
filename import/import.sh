#!/bin/sh
# $1 is the Trove ID. $2 is the sequence letter.
DATE=`date +%Y-%m-%d`
sips -s format jpeg -s formatOptions normal *.png --out $1$2.jpg
open $1$2.jpg
cat > $1$2.txt <<EOL
title       :
key         : ${1}${2}
category    :
date_updated: ${DATE}
precis      :

tags:
    -

insertions:
    - date       : 1890-
      publication: KatoombaTimes
      page       :
      trove_id   : ${1}
EOL
choc $1$2.txt
read -p "Press [Enter] when editing is complete, or Ctrl-C to cancel."
mv $1$2.jpg ../article-img
mv $1$2.txt ../articles
rm *.png
