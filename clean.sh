#!/bin/bash

echo "////Environment Clean////"
tmux kill-session -t test
rm -rf /volume/$1/_R\@W_*
echo "////Clean Finish////"
