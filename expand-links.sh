#!/bin/sh

NORM=`realpath -s "$1"`
TARGET="$NORM"

while [ true ]
do
	echo $TARGET
	DIR=`dirname "$TARGET"`
	LINK=`readlink "$TARGET"`
	if [ -z "$LINK" ]; then
		break
	fi
	NEXT=`realpath -s "$DIR/$LINK"`
	if [ "$TARGET" = "$NEXT" ]; then
		break
	fi
	TARGET="$NEXT"
done
