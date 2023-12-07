#!/usr/bin/env python3 
import json
import boto3
import os
import re
import pandas as pd


def find_book_by_date(date, df):
    date = int(date)
    matching_book = df[df['Date'] == date]
    return matching_book.to_dict('records')[0] if not matching_book.empty else None

def main():
    # Read the CSV file into a pandas DataFrame
    df = pd.read_csv('my_sample_data.csv')

    # Prompt the user for a date
    user_date = input("Enter a date (YYYY): ")

    # Find the book with the entered date
    matching_book = find_book_by_date(user_date, df)

    # Display the result
    if matching_book:
        print(f"Book found for the date {user_date}:")
        print(f"Title: {matching_book['Title']}")
        print(f"Author: {matching_book['Author']}")
        print(f"Date: {matching_book['Date']}")
    else:
        print(f"No match found for the date {user_date}")

if __name__ == "__main__":
    main()