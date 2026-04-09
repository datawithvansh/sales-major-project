import pandas as pd
import os
from sqlalchemy import create_engine
import time
import logging

logging.basicConfig(
    filename='logs/ingest_db.log',
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filemode='a'
)

engine = create_engine('sqlite:///inventory.db')

def ingest_db(df, table_name, engine):
    '''this function will ingest dataframes into database table'''
    df.to_sql(table_name, con=engine, if_exists='replace', index=False)
    
def load_raw_data():
    '''this function will load csv as data frame and ingest into db'''
    start= time.time()
    for file in os.listdir('data'):
        if '.csv' in file:        
            df = pd.read_csv('data/' + file)  
            logging.info(f'Ingesting {file} in db' ) 
            ingest_db(df ,file[:-4],engine)
    end= time.time()
    total_time=(end-start)/60
    logging.info('----------Ingestion Complete-----------')
    logging.info(f'\nToatal Time Taken : {total_time} minutes')

if __name__ == '__main__':
    load_raw_data()