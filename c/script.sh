#!/bin/bash
set -e

# 1 - Curl loads the chosen wiki page and saves the content of the website as kommune.list.html
curl -s https://en.wikipedia.org/wiki/List_of_municipalities_of_Norway > kommune.list.html

# 2 - Remove whitespace characters and tabs.
	# tr -d '\n\t' selects newline char. and tabs to be removed. Which means we end up with the whole page on one line.
	# It is a good way to prepare the file for text editing tools like grep and sed. 
	# Redirect the outcome to new file as "kommune.list.no.newline.html"
cat "kommune.list.html" | tr -d '\n\t' > kommune.list.no.newlines.html

# 3 - Extracting and formatting data 
sed -E 's/.*<table class="sortable wikitable">(.*)<\/table>.*/\1/g' kommune.list.no.newlines.html |  
    sed 's/<\/table>/\n/g' | 
    sed -n '1p' | 
    sed -E 's/<tbody[^>]*>(.*)<\/tbody>/\1/g' | 
    sed -E 's/<tr[^>]*>//g' | 
    sed 's/<\/tr>/\n/g' | 
    sed -E 's/<td[^>]*>//g' | 
    sed 's/<\/td>/\t/g' | 
    sed 's/<span[^>]*>//g; s/<\/span>//g' | 
    sed 's/title\s*=\s*"[^"]*"//g; s/title\s*="//g' |
    sed '1d' > kommune.table.txt

## This command resulted in a long sequence of sed commands as I added more and more filtering of the data to make it as clean as possible.
## The result of each command is piped to the next command.
##  1 line: Extract everything between the table start and end tag, of the specific “sortable wikitable” table.
##  2 line: Replaces the </table> end-tag with a newline. All interesting data remain on line 1.
##  3 line: sed -n silently prints line 1 (ditching line 2 with all its content).
##  4 line: extracts everything between the tbody start and end tag.
##  5 line: find all <TR> START tags and "removes" them (replace with blank character)
##  6 line: find all </TR> END tags and relpaces them with a (\n) new line.
##  7 line: find all <TD> START tags and "removes" them (replace with blank character)
##  8 line: find all </TD> END tags and relpaces them with a (\t) tab.
##  9 line: remove unwanted span tags
## 10 line: remove unwanted title attributes (spaces in the title messed up our "colums")
## 11 line: remove the first line (this contains the unwanted table header row)

## To sum up; we have removed all html tags, and then the data is formated into three columns separeated by tabs. 
## This cleaned data is saved in a new file: kommune.table.txt

# 4 - Remove single space characters
	## I noticed a bug in the example script, that if the municipality name has a double name like "Indre østfold" 
	## the name would be "Indre" and the population would be "østfold". 
	## Also if population is written as "1 350" instead of "1,350" the population would end up as 1.
	## I decided to remove all single space characters
sed 's/ //g' kommune.table.txt > kommune.table.nospace.txt

# 5 - selecting column 2 and 5 for our selected file. This cmd selects only the URL and the populations column.
	## By looking at the original wiki page you can see that column 2 and 5 are the ones that have the data that we want. 
	## column 2 and 5 are then chosen by using cut and then is saved into a new file called 'columns2and5.txt'
cut -f 2,5 kommune.table.nospace.txt > columns2and5.txt



# 6 - Build real data to be used
	# extract the url part (from hrefs of <a>), and build the complete URL with the "https://en.wikipedia.org" as the start of the url. 
	# Use the municipality name inside the <a> tag.
	# Also add the population by adding "$2" (column 3) at the end.
awk 'match($0, /href="[^"]*"/){url=substr($0, RSTART+6, RLENGTH-7)} match($0, />[^<]*<\/a>/){printf("%s%s\t%s\t%s\n", "https://en.wikipedia.org", url, substr($0, RSTART+1, RLENGTH-5), $2)}' columns2and5.txt > kommune.data.txt 

# Tells us in the terminal that the while loop is started.
echo "Starting While-loop..."

# clears data.with.everything.txt when this cmd runs. Means we start with a blank canvas every time
truncate -s 0 kommune.data.with.everything.txt 

# 7 - The while loop:
# The While cmd is a loop, in this case it goes through every line in data.txt and extract the url, place and population.
# The value of the data in each column (kommune.data.txt) is read into the variables url, place and population for each line
while read url place population; do
	# outputs the real URL to the terminal, this is a great way to watch progress of the script.
    echo "Calling URL $url"

	# run curl with the url and save the content in variable pageHtml
    pageHtml="$(curl -s "$url")"

	# Extract the coordinates pageHtml by using grep and sed. The lat and lon stands for the latitude and longitude  
    lat=$(echo "$pageHtml" | grep -o '<span class="latitude">[^<]*' | head -n 1 | sed 's/<span class="latitude">//' )
    lon=$(echo "$pageHtml" | grep -o '<span class="longitude">[^<]*' | head -n 1 | sed 's/<span class="longitude">//' )
		
	# Using awk's math function we can make a coordinates to decimals converter.
    lat_dec=$(echo "$lat" | awk -F'[^0-9.]+' '{print ($1+($2*60+$3)/3600)}')
	lon_dec=$(echo "$lon" | awk -F'[^0-9.]+' '{print ($1+($2*60+$3)/3600)}')
		
	# prints the right coords and population (now defined as variables using "$..") to our terminal. Easy way to see if the script worked and watch progress.
    echo "lat=$lat_dec, lon=$lon_dec, population=$population"
    
	# Append the url, place, coords, and population to "kommune.data.with.everthing.txt"
	# Using printf to format and print a tab-separated line with all the given values (ending with a newline) appending to the file kommune.data.with.everthing.txt
    printf "%s\t%s\t%s\t%s\t%s\n" "$url" "$place" "$lat_dec" "$lon_dec" "$population" >> kommune.data.with.everything.txt
done < kommune.data.txt

# Tells us in the terminal that the while loop is done.
echo "While-loop done..."

# 8 - 
# Add a span tag around the coords. Then wrap a <p> tag around the complete content of url (<a> tag), coordinates and population.
# Also adds the words "is here" around the url, I added to words "Lat:" and "Lon:" to make it clearer what the numbers are and the words "population" before it lists the population.
# Using awk with -F'\t' to tell awk that the input file is tab-separated.
awk -F'\t' '{printf "<p><a href=\"%s\">%s</a> is here: <span>Lat: %s, Lon: %s</span>. Population: %s</p>\n", $1, $2, $3, $4, $5 }' "kommune.data.with.everything.txt" > "pretty.kommune.data.html"

# 9 - Since sed is a text editor tool we can use it make I render a page. by already making at simple template with some customizations. 
# Make sed find the file the "<!--CONTENT-->" in the template file, then it replaces it with pretty.data.txt
# It is then save the new file as kommune.final.html and as the name tells us; this is the final file.
sed -e '/<!--CONTENT-->/r pretty.kommune.data.html' -e '/<!--CONTENT-->/d' 'page.template.txt' > kommune.final.html

# 10 - copies our final file to the apache server. we have to use sudo thats why we have to add the second command to change to ownership back to www:data.
sudo cp kommune.final.html /var/www/miasann-exam.com/public_html/c.final.html
sudo chown -R www-data:www-data /var/www/miasann-exam.com/public_html/c.final.html