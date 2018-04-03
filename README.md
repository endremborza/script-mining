# Heroes and Heroines

I scraped over a 1000 movie scripts and looked at how male and female roles appear in them. And more importantly, how make and female audiences react, to these differences, based on their rating of the movies.

Two projects based on movie screenplays have been published on pudding, based on [screen direction](https://pudding.cool/2017/08/screen-direction/) and [lines of dialogue](https://pudding.cool/2017/03/film-dialogue/). They use the same data but the [method](https://github.com/matthewfdaniels/scripts/) the first article provides for finding it is not very effective, so I had to make my own script database, with about half the number of scripts they had. 

## Who is a hero and what do they say and do?

As hard as finding out who a hero is, here I will use the easiest answer I could think of. That is, the heroes of a movie are the ones listed in the top 2 of the 'top billed cast' on imdb's page. Also, somewhat politically incorrectly, I will use hero and heroine phrases to separate these heroes into two genders, based on the names of the actors who portray them. 

What they say and do is deduced from the script. Whatever appears in the second word of bigrams (basically two words after one another), where the first word corresponds to the character name of someone, that is what they do or say. Screen direction, narration and dialogue are equally present in the script and are not separated here. To make sure that this is appropriately restricted to actions or relevant words, all names related to other characters are discarded.

About two thirds of all characters are portrayed by male actors, but this isn't heavily correlated with billing order, as seen in this first histogram. However, one significant difference is that the male occurences are half as common in second billing status as first one, but in the female cases, a similar dropoff only occurs after the second billing, as the first two are about equal.

Also, the hero definition seems to make at least some sense as the higher billed members appear more often.

![image](bar-hist.png)

Looking at the number of positive words that follow our heroes and heroines in this second graph, here it is even more articulated, that there is much less difference between first and second billing in the case of women than men. Second billing women even get more positive words than first billing ones.

![image](sum-sent.png)



![image](pos-tfidf.png)


![image](neg-tfidf.png)



For a little more in-depth insight, I used [spacyr](https://github.com/quanteda/spacyr), the R wrapper for the python package spacy, that does part of speech recognition. This way I could find verbs that immediately follow the occurrance of a name and adjectives that appear right before, or in the structur 'character be ADJ', as spacy can also recognize different forms of the word be. 

## Data

The data was collected from [imdb](www.imdb.com) and [imsdb](www.imsdb.com), as I matched all the available scripts to imdb searches during scraping and data cleaning. The cast, with billing order and ratings broken down into demographics were collected from imdb.

