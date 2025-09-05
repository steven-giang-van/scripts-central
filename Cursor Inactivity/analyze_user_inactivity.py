#!/usr/bin/env python3
"""
User Inactivity Analysis Script

This script analyzes user activity data to find users who have been inactive 
for 14 consecutive days, with support for excluding specific dates and 
resetting counters when users are active on excluded dates.

Usage: python3 analyze_user_inactivity.py [csv_file]
"""

import pandas as pd
from datetime import datetime, timedelta
import sys
import os



def analyze_user_inactivity(csv_file, excluded_dates=None, inactive_threshold=14, exclude_weekends=True):
    """
    Analyze user activity data to find users inactive for specified consecutive days.
    
    Args:
        csv_file (str): Path to CSV file with user activity data
        excluded_dates (list): List of datetime objects to exclude from analysis (holidays)
        inactive_threshold (int): Number of consecutive inactive days to flag
        exclude_weekends (bool): Whether to automatically exclude weekends from counting

    
    Returns:
        dict: Analysis results including inactive users and statistics
    """
    
    if excluded_dates is None:
        excluded_dates = []
    
    # Read the CSV file
    try:
        df = pd.read_csv(csv_file)
    except FileNotFoundError:
        print(f"Error: File '{csv_file}' not found.")
        return None
    except Exception as e:
        print(f"Error reading file: {e}")
        return None
    
    # Validate required columns
    required_columns = ['Date', 'Email', 'Is Active']
    missing_columns = [col for col in required_columns if col not in df.columns]
    if missing_columns:
        print(f"Error: Missing required columns: {missing_columns}")
        return None
    
    # Convert Date column to datetime
    df['Date'] = pd.to_datetime(df['Date'])
    
    # Sort by Email and Date to process chronologically
    df = df.sort_values(['Email', 'Date'])
    
    inactive_users = []
    user_reports = []
    
    # Process each user
    for email in df['Email'].unique():
        user_data = df[df['Email'] == email].copy()
        
        consecutive_inactive_days = 0
        max_consecutive_inactive = 0
        inactive_start_date = None
        last_active_date = None
        
        # Count total active and inactive days
        total_days = len(user_data)
        active_days = len(user_data[user_data['Is Active'] == True])
        inactive_days = total_days - active_days
        
        # Process each date for this user
        for _, row in user_data.iterrows():
            current_date = row['Date']
            is_active = row['Is Active']
            
            # Check if this date should be excluded (holidays or weekends)
            is_excluded = False
            
            # Check for explicitly excluded dates (holidays)
            if current_date.date() in [d.date() for d in excluded_dates]:
                is_excluded = True
            
            # Check for weekends (Saturday=5, Sunday=6)
            if exclude_weekends and current_date.weekday() >= 5:
                is_excluded = True
            
            if is_excluded:
                # If user was active on excluded date, reset counter and update last active date
                if is_active:
                    consecutive_inactive_days = 0
                    inactive_start_date = None
                    last_active_date = current_date
                # If inactive on excluded date, don't count it but don't reset either
                continue
            
            # Process regular dates
            if is_active:
                # User is active, reset counter and update last active date
                consecutive_inactive_days = 0
                inactive_start_date = None
                last_active_date = current_date
            else:
                # User is inactive
                if consecutive_inactive_days == 0:
                    inactive_start_date = current_date
                consecutive_inactive_days += 1
                max_consecutive_inactive = max(max_consecutive_inactive, consecutive_inactive_days)
        
        # Create user report
        user_report = {
            'Email': email,
            'Total_Days': total_days,
            'Active_Days': active_days,
            'Inactive_Days': inactive_days,
            'Current_Consecutive_Inactive': consecutive_inactive_days,
            'Max_Consecutive_Inactive': max_consecutive_inactive,
            'Activity_Rate': f"{(active_days/total_days)*100:.1f}%",
            'Date_Range': f"{user_data['Date'].min().strftime('%Y-%m-%d')} to {user_data['Date'].max().strftime('%Y-%m-%d')}",
            'Last_Active_Date': last_active_date.strftime('%Y-%m-%d') if last_active_date else 'Never'
        }
        user_reports.append(user_report)
        
        # Check if user meets inactive threshold
        if consecutive_inactive_days >= inactive_threshold:
            inactive_users.append({
                'Email': email,
                'Consecutive_Inactive_Days': consecutive_inactive_days,
                'Inactive_Since': inactive_start_date.strftime('%Y-%m-%d') if inactive_start_date else 'Unknown',
                'Max_Consecutive_Inactive': max_consecutive_inactive,
                'Last_Active_Date': last_active_date.strftime('%Y-%m-%d') if last_active_date else 'Never'
            })
    
    # Calculate summary statistics
    total_users = len(user_reports)
    users_with_activity = len([u for u in user_reports if u['Active_Days'] > 0])
    avg_activity_rate = sum(float(u['Activity_Rate'].rstrip('%')) for u in user_reports) / total_users if total_users > 0 else 0
    
    return {
        'inactive_users': inactive_users,
        'user_reports': user_reports,
        'summary': {
            'total_users': total_users,
            'users_with_activity': users_with_activity,
            'avg_activity_rate': avg_activity_rate,
            'inactive_threshold': inactive_threshold,
            'excluded_dates': excluded_dates,
            'exclude_weekends': exclude_weekends
        }
    }

def print_results(results):
    """Print formatted analysis results."""
    
    if not results:
        print("No results to display.")
        return
    
    inactive_users = results['inactive_users']
    summary = results['summary']
    
    print("User Inactivity Analysis Results")
    print("=" * 60)
    
    # Show exclusion information
    exclusions = []
    if summary['exclude_weekends']:
        exclusions.append("weekends")
    if summary['excluded_dates']:
        excluded_str = ', '.join([d.strftime('%m/%d') for d in summary['excluded_dates']])
        exclusions.append(f"holidays ({excluded_str})")
    
    if exclusions:
        print(f"Excluded from counting: {', '.join(exclusions)}")
    
    print(f"Looking for users inactive for {summary['inactive_threshold']}+ consecutive days...")
    print("-" * 60)
    
    if inactive_users:
        print(f"\nFound {len(inactive_users)} users inactive for {summary['inactive_threshold']}+ consecutive days:\n")
        
        for i, user in enumerate(inactive_users, 1):
            print(f"{i}. {user['Email']}")
            print(f"   Current consecutive inactive days: {user['Consecutive_Inactive_Days']}")
            print(f"   Inactive since: {user['Inactive_Since']}")
            print(f"   Last active date: {user['Last_Active_Date']}")
            print(f"   Max consecutive inactive period: {user['Max_Consecutive_Inactive']} days")
            print()
    else:
        print(f"\nNo users found with {summary['inactive_threshold']}+ consecutive inactive days.")
    
    # Summary statistics
    print(f"\nSummary Statistics:")
    print(f"Total users: {summary['total_users']}")
    print(f"Users with any activity: {summary['users_with_activity']}")
    print(f"Average activity rate: {summary['avg_activity_rate']:.1f}%")
    print(f"Users inactive for {summary['inactive_threshold']}+ days: {len(inactive_users)}")

def print_detailed_report(results):
    """Print detailed report of all users sorted by inactivity."""
    
    if not results:
        print("No results to display.")
        return
    
    user_reports = results['user_reports']
    summary = results['summary']
    
    # Sort by current consecutive inactive days (descending)
    user_reports.sort(key=lambda x: x['Current_Consecutive_Inactive'], reverse=True)
    
    print("\nDetailed User Activity Report")
    print("=" * 80)
    print("Users sorted by current consecutive inactive days:\n")
    
    for i, user in enumerate(user_reports, 1):
        print(f"{i:2d}. {user['Email']}")
        print(f"     Date Range: {user['Date_Range']}")
        print(f"     Total Days: {user['Total_Days']}, Active: {user['Active_Days']}, Inactive: {user['Inactive_Days']}")
        print(f"     Activity Rate: {user['Activity_Rate']}")
        print(f"     Last Active Date: {user['Last_Active_Date']}")
        print(f"     Current Consecutive Inactive: {user['Current_Consecutive_Inactive']} days")
        print(f"     Max Consecutive Inactive: {user['Max_Consecutive_Inactive']} days")
        print()
    
    # Show users with 7+ consecutive inactive days
    high_inactive = [u for u in user_reports if u['Current_Consecutive_Inactive'] >= 7]
    
    if high_inactive:
        print(f"\nUsers with 7+ consecutive inactive days:")
        print("-" * 50)
        for user in high_inactive:
            print(f"- {user['Email']}: {user['Current_Consecutive_Inactive']} days")
    else:
        print("\nNo users with 7+ consecutive inactive days found.")

def main():
    """Main function to run the analysis."""
    
    # Default CSV file
    default_csv = 'cursor_analytics_8968057_2025-07-14T21_47_53.122Z.csv'
    
    # Check if CSV file argument provided
    if len(sys.argv) > 1:
        csv_file = sys.argv[1]
    else:
        csv_file = default_csv
    
    # Check if file exists
    if not os.path.exists(csv_file):
        print(f"Error: File '{csv_file}' not found.")
        print(f"Usage: python3 {sys.argv[0]} [csv_file]")
        sys.exit(1)
    
    # Define excluded holidays (weekends are automatically excluded)
    excluded_holidays = [
        datetime(2025, 7, 4),   # 7/4 - Independence Day
        datetime(2025, 7, 7),   # 7/7 - Extra weekened
    ]
    
    # Run analysis with automatic weekend exclusion
    results = analyze_user_inactivity(csv_file, excluded_holidays, inactive_threshold=14, exclude_weekends=True)
    
    if results:
        print_results(results)
        
        # Ask if user wants detailed report
        try:
            show_detailed = input("\nShow detailed report for all users? (y/n): ").lower().strip()
            if show_detailed == 'y':
                print_detailed_report(results)
        except KeyboardInterrupt:
            print("\nAnalysis complete.")

if __name__ == "__main__":
    main() 
