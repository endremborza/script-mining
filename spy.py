import pandas as pd
import spacy

nlp = spacy.load('en')

df = pd.read_csv('huhas.csv')

tokens = []
lemma = []
pos = []

for doc in nlp.pipe(df['ngram'].astype('unicode').values, batch_size=50,
                        n_threads=3):
    if doc.is_parsed:
        tokens.append([n.text for n in doc])
        lemma.append([n.lemma_ for n in doc])
        pos.append([n.pos_ for n in doc])
    else:
        # We want to make sure that the lists of parsed results have the
        # same number of entries of the original Dataframe, so add some blanks in case the parse fails
        tokens.append(None)
        lemma.append(None)
        pos.append(None)

df['species_tokens'] = tokens
df['species_lemma'] = lemma
df['species_pos'] = pos

for i in range(3):
    for col in ['tokens','lemma','pos']:
       df['sep-' + col + str(i+1)] = df['species_' + col].apply(lambda x: x[i] if (x != None and len(x) > i) else None)

df.to_csv('spcy-sep.csv',index=False)


for col in ['tokens','lemma','pos']:
    keys = [c for c in list(df) if ('sep-' + col) in c]
    df = df.melt('Unnamed: 0',value_name=col,value_vars=keys).drop('variable',1)


