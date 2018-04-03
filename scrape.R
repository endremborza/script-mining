require(httr)
require(rvest)
require(dplyr)
require(stringr)
library(gender)
require(tidytext)
library(tidyverse)
library(ggplot2)


#options(dplyr.print_max = 100)

scrape_letter <- function(url){
  return(read_html(url) %>% html_node('#mainbody > table:nth-child(3) > tr:nth-child(1) > td:nth-child(3)')  %>%
           html_nodes('a') %>% html_attr('href'))
}

get_script <- function(url){
  try(return(read_html(url) %>% html_node('pre')))
  return('NA')
}

try_html <- function(url){
  try(return(read_html(url)))
  return('NA')
}

try_text <- function(page){
  try(return(html_text(page)))
  return('NA')
}

scrape_imdbsearch <- function(url){
  return(read_html(url) %>% html_node(xpath = '//*[@name="tt"]') %>%
           xml_parent() %>% xml_siblings() %>% html_node('a') %>% html_attr('href') %>% (function (x) x[1]) )
}

scrape_imdbtitle <- function(titleblock){
  return(c('ititle'=titleblock %>% html_text(),'year'=titleblock %>% html_node('span') %>% html_text()))
}

scrape_plusinfo <- function(infopage){
  return(c('length'= infopage %>% html_node('time') %>% html_attr('datetime'),
           'rating' = infopage %>% html_node('meta') %>% html_attr('content')
  ))
}


scrape_imdbmeta <- function(metapage){
  return(c(scrape_imdbtitle(metapage %>% html_node('h1')),
           scrape_plusinfo(metapage %>% html_node('div.subtext'))
  ))
}  


scrape_imdbratings <- function(url){
  return(read_html(url) %>% html_node(xpath = '//*[@name="tt"]') %>%
           xml_parent() %>% xml_siblings() %>% html_node('a') %>% html_attr('href') %>% (function (x) x[1]) )
}

scrape_imdb <- function(body){
  try(
    return(c(body %>% html_node(xpath='/html/body/div[1]/div/div[4]/div[5]/div[1]/div/div/div[2]/div[2]/div/div[2]/div[2]') %>%
               scrape_imdbmeta(),
             body %>% html_node('table.class_list') %>% html_nodes('tr')
    ))
  )
  return(c(iyear='NA',ititle='NA',length='NA',rating='NA'))
}




urls <- paste('http://www.imsdb.com/alphabetical/',c("0",letters),sep='') %>% lapply(scrape_letter)


pres <- urls %>% unlist() %>% gsub(pattern="/Movie Scripts/",replacement="http://www.imsdb.com/scripts/") %>%
  gsub(pattern=" ",replacement="-") %>%
  gsub(pattern="-Script.html",replacement=".html") %>% lapply(get_script)

titles = urls %>% unlist() %>% gsub(pattern="/Movie Scripts/",replacement="") %>%
  gsub(pattern=" Script.html",replacement="") %>%
  sub(pattern="(.+), The$", replacement="The \\1", perl=TRUE)

imdb = paste('http://www.imdb.com/find?ref_=nv_sr_fn&q=',
             titles%>%
               gsub(pattern=" ",replacement="+"),
             '&s=all',sep="") %>% lapply(scrape_imdbsearch) %>% unlist() %>%
  str_extract("(tt[0-9]+)")

meta = paste('http://www.imdb.com/title/',imdb,sep="") %>% lapply(try_html)

rating = paste('http://www.imdb.com/title/',imdb,'/ratings/',sep="") %>% lapply(try_html)

imeta <- meta %>% lapply(scrape_imdb) %>% unlist() %>% matrix(nrow=4) %>% t() %>% data.frame()


df_all <- df[1:5,] %>% filter(script!='NA') %>%
  mutate(c(mdata,m2,m3,m4)=scrape_imdb(imeta[[1]]))


get_rolenames <- function(row){
  try(return(
    row %>% html_node(xpath='/html/body/div[1]/div/div[4]/div[5]/div[3]/div[5]/table') %>%
      html_nodes('td') %>% html_text() %>% trimws() %>%
      tail(-2) %>% matrix(nrow=4) %>% t() %>% data.frame(stringsAsFactors = F) %>%
      select(c(X1,X3)) %>% mutate(X3 = sub("( \\n  \\n  \\n).+","",X3)) %>%
      mutate(fname = X1 %>% sapply( (function (x) unlist(strsplit(x,split=" "))[1]) ) ) %>%
      mutate(gender = fname %>% sapply( function (x) gender(x)[2])) %>% 
      mutate(bgen = ifelse(gender>0.85,1,0)) %>%
      mutate(problem=ifelse(gender<0.85 & gender>0.15,1,0)) %>% mutate(billing = seq())
    # %>% filter(problem==0) %>%
    #group_by(bgen) %>% summarise(X3=paste(X3,collapse=',')) %>% select(X3) %>% t()
  ))
  return(c('',''))
}

roles <- meta %>% lapply(get_rolenames)



get_ratings <- function(page){
  try(return(page %>% 
               html_node(xpath='/html/body/div[1]/div/div[4]/div[3]/div[1]/section/div/table[2]') %>%
               html_table(fill=T)# %>% gsub(pattern="\\s+", replacement=" ")
             
  ))
  return('NA')
}


rates <- rating %>% lapply(get_ratings)

df <- cbind(data_frame(imdb=imdb,title=titles,script=pres %>% sapply(try_text),
                       url=urls %>% unlist(),irating=rates,roles=roles),imeta)

df_tok <- df %>%
  select(imdb,script) %>%
  unnest_tokens(ngram, script, token = "ngrams", n = 2, n_min = 2) %>%
  separate(ngram, c("word1", "word2"), remove=FALSE, sep = " ")


### this is an absolutely disgusting solution but I got tired of a lot of things not working

df_roles <- df$roles

final_roles <- data.frame()

for(i in 1:length(df_roles)){
  try({
    df_roles[[i]]$imdb <- df$imdb[i]
    df_roles[[i]]$billing <- seq(dim(df_roles[[i]])[1])
    final_roles <- rbind(final_roles,df_roles[[i]])
    final_roles <- rbind(final_roles,
                         data.frame(imdb=df$imdb[i],X3=c('he','she'),problem=0,
                                    gender=c(1,0),bgen=c(1,0),billing=0,X1=c('he','she'),
                                    fname='fname')
    )
  })
}

final_roles <- final_roles %>% separate(X3,c('n1','n2','n3','n4','n5','n6','n7'),sep= "\\s+")

out <- data.frame()

for(col in c('n1','n2','n3','n4','n5','n6','n7')){
  out <- rbind(out,final_roles %>% mutate(fing = final_roles[,col]))
}

out <- out %>% select(fing,imdb,billing,bgen,problem,X1) %>% mutate(word1=tolower(fing)) %>%
  mutate(tabu=word1) %>% unique()

huha <- out %>% inner_join(df_tok,by=c('imdb','word1')) %>% filter(billing < 16) %>%
  mutate(tabu=word2) %>% anti_join(out,by="tabu")







library(ggplot2)

huha %>% select(billing,bgen) %>% mutate(gender=ifelse(bgen==1,'male','female')) %>%
  ggplot(aes(billing, fill=gender)) + 
  geom_histogram(position = "stack", binwidth=1) +
  ggtitle("Appearances in script by billing order (0 is he/she)")

#how many times they appear in the script, not just lines
ggsave("hist-bill.png")

for_sent <- huha %>% mutate(gender=ifelse(bgen==1,'male','female')) %>%
  inner_join(get_sentiments("bing"), by = c(word2 = "word"))

for_sent %>% mutate(pos=ifelse(sentiment=="positive",1,0)) %>%
  filter(!is.na(gender)) %>%
  group_by(billing,gender) %>% 
  summarise(positivity = sum(pos)) %>% ggplot(aes(billing,positivity,color=gender)) + geom_line() +
  ggtitle("Positivity score to billing by genders")

ggsave("sum-sent.png")



for_tfidf <- huha %>% filter(problem==0) %>% mutate(gender=ifelse(bgen==1,'male','female')) %>%
  inner_join(get_sentiments("bing"), by = c(word2 = "word")) %>%
  mutate(heroine=ifelse(bgen==0 & billing != 0 & billing < 3,1,0)) %>%
  mutate(hero=ifelse(bgen==1 & billing != 0 & billing < 3,1,0)) %>%
  mutate(status=ifelse(hero==1,'hero',gender)) %>%
  mutate(status=ifelse(heroine==1,'heroine',status))


for_tfidf %>% filter(sentiment=="positive") %>%
  count(status, word2, sort = TRUE) %>%
  ungroup() %>%
  bind_tf_idf(word2, status, n) %>%
  arrange(desc(tf_idf)) %>%
  group_by(status) %>%
  top_n(4, tf_idf) %>%
  ungroup() %>%
  mutate(word = reorder(word2, tf_idf)) %>%
  ggplot(aes(word, tf_idf, fill = status)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ status, scales = "free") +
  ylab("tf-idf") +
  coord_flip() +
  ggtitle("Most characteristic positive words")

ggsave("pos-tfidf.png")

for_tfidf %>% filter(sentiment=="negative") %>%
  count(status, word2, sort = TRUE) %>%
  ungroup() %>%
  bind_tf_idf(word2, status, n) %>%
  arrange(desc(tf_idf)) %>%
  group_by(status) %>%
  top_n(4, tf_idf) %>%
  ungroup() %>%
  mutate(word = reorder(word2, tf_idf)) %>%
  ggplot(aes(word, tf_idf, fill = status)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ status, scales = "free") +
  ylab("tf-idf") +
  coord_flip() +
  ggtitle("Most characteristic positive words")

ggsave("neg-tfidf.png")


require(spacyr)
## Loading required package: spacyr
spacy_initialize()

df %>%
  select(imdb,script) %>%
  spacy_parse(script, pos = TRUE, tag = TRUE)

scripts <- df$script

names(scripts) <- imdb

#start: 17:34
#sp_tok <- spacy_parse(scripts[1:100],tag=TRUE,pos=TRUE)


df_toks <- df %>%
  select(imdb,script) %>%
  unnest_tokens(ngram, script, token = "ngrams", n = 3, n_min = 2) %>%
  separate(ngram, c("word1", "word2","word3"), remove=FALSE, sep = " ")

outs <- out %>% select(imdb,billing,bgen,problem,X1,word1)

outs2 <- out %>% mutate(word2=word1) %>%
  select(imdb,billing,bgen,problem,X1,word2)

huhas <- outs %>% inner_join(df_toks,by=c('imdb','word1')) %>% filter(billing < 16) %>%
  mutate(tabu=word2) %>% anti_join(outs,by="tabu") %>% rbind(
    outs2 %>% inner_join(df_toks,by=c('imdb','word2')) %>%
      filter(billing < 16) %>%
      mutate(tabu=word2) %>% anti_join(out,by="tabu")
  )