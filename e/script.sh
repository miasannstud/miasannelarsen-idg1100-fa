#!/bin/bash

# curl downloads the website and then saves the results as "kommune.list.txt" on my machine
curl -s https://en.wikipedia.org/wiki/List_of_municipalities_of_Norway > kommune.list.txt

# Remove whitespace charaters and tabs.
# tr -d '\n\t' selects newline char. and tabs to be removed. Which means we end up with the whole page on one line.
# It is a good way to prepare the file for text editing tools like grep and sed. 
# We redirect the outcome into a new file called "kommune.oneline.txt"
cat kommune.list.txt | tr -d '\n\t'  >  kommune.oneline.txt 

# Everything is on the same line extracting our table in to a new file
# Cut out all text between <table class="sortable wikitable"> and </table> and save to kommune.table.txt 
sed -E 's/.*<table class="sortable wikitable">(.*)<\/table>.*/\1/g' kommune.oneline.txt > kommune.table.txt

# A small html page template, with some uniqeness!
page_template='
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E solution</title>
</head>
<body>
    <style>
        * {
            font-family: Verdana, Geneva, Tahoma, sans-serif;
        }
        
        body {
            background-color:lightblue;
            margin: 0px;
        }
        
        #top {
            background-color:rgb(116, 173, 194);
            padding: 20px;
            color: rgb(14, 13, 13);
        }

        p {
            margin: 20px;
        }

        table, th, td {
            text-align: left;
            border: 1px solid;
        }
    </style>
    <div id="top">
        <h1>Mia Sanne-Larsens fancy wiki list</h1>
        <h2>Welcome to my super cool list of muncipalitites</h2>
        <h3>proudly stolen from wikipedia</h3>
    </div>
    <table>
    '"$(cat "kommune.table.txt")"'
    </table>
</body>
</html>
'

# Echoes the page template we see over into a new file called e.final.html this is our final file!
echo "$page_template" > "e.final.html"
