#!/bin/bash

rm PulledDataFiles/*;
cd PulledDataFiles;
xargs -n 1 curl -O <../theList.txt

find . -name '*' -size 1635c -exec mv {} junk \;
rm junk;
cd ..;

