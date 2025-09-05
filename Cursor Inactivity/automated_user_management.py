#!/usr/bin/env python3
"""
Automated User Management Script with Cursor API Integration

This script automates the process of analyzing user activity and managing memberships
by integrating with the Cursor API to fetch real-time user activity data and
potentially remove inactive users from groups.

Features:
- Fetch user activity data from Cursor API
- Analyze inactivity patterns with configurable thresholds
- Automated group membership management
- Email notifications for actions taken
- Configurable exclusion rules (holidays, weekends)
- Audit logging for compliance

Usage: python3 automated_user_management.py [--config config.yaml] [--dry-run]
"""

import requests
import pandas as pd
import yaml
import json
import logging
from datetime import datetime, timedelta
import argparse
import sys
import os
from typing import Dict, List, Optional, Tuple
import time

class CursorAPIClient:
    """Client for interacting with Cursor API."""
    
    def __init__(self, api_key: str, base_url: str = "https://api.cursor.sh"):
        self.api_key = api_key
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        })
    
    def get_user_activity(self, start_date: datetime, end_date: datetime) -> List[Dict]:
        """
        Fetch user activity data from Cursor Admin API.
        
        Args:
            start_date: Start date for activity range
            end_date: End date for activity range
            
        Returns:
            List of user activity records
        """
        try:
            # Use the real Cursor Admin API endpoint
            endpoint = f"{self.base_url}/teams/daily-usage-data"
            
            # Convert dates to epoch milliseconds as required by the API
            start_epoch = int(start_date.timestamp() * 1000)
            end_epoch = int(end_date.timestamp() * 1000)
            
            payload = {
                'startDate': start_epoch,
                'endDate': end_epoch
            }
            
            response = self.session.post(endpoint, json=payload)
            response.raise_for_status()
            
            data = response.json().get('data', [])
            
            # Transform the data to match our expected format
            transformed_data = []
            for record in data:
                if 'email' in record and 'isActive' in record:
                    # Debug: Check j.brannum's raw data
                    if record['email'] == 'j.brannum@slingshotaerospace.com':
                        logging.info(f"DEBUG: j.brannum raw record: {record}")
                    
                    # Handle date conversion - API returns timestamps in milliseconds
                    record_date = record.get('date')
                    if record_date is None or record_date == 0:
                        # Use the start of analysis period for users with no activity data
                        record_date = start_date.isoformat()
                    elif isinstance(record_date, (int, float)):
                        # Convert timestamp from milliseconds to ISO format
                        dt = datetime.fromtimestamp(record_date / 1000)
                        record_date = dt.isoformat()
                    elif isinstance(record_date, str) and record_date.startswith('1970-01-01'):
                        # Handle Unix epoch strings
                        record_date = start_date.isoformat()
                    
                    transformed_data.append({
                        'date': record_date,
                        'user_id': record.get('email', ''),  # Use email as user_id
                        'user_email': record['email'],
                        'is_active': record['isActive']
                    })
            
            return transformed_data
            
        except requests.exceptions.RequestException as e:
            logging.error(f"Failed to fetch user activity: {e}")
            return []
    

    
    def get_all_members(self) -> List[Dict]:
        """
        Fetch all team members from Cursor Admin API (including owners).
        
        Returns:
            List of all team members
        """
        try:
            endpoint = f"{self.base_url}/teams/members"
            response = self.session.get(endpoint)
            response.raise_for_status()
            
            return response.json().get('teamMembers', [])
            
        except requests.exceptions.RequestException as e:
            logging.error(f"Failed to fetch all team members: {e}")
            return []
    
    def get_team_members(self) -> List[Dict]:
        """
        Fetch all team members from Cursor Admin API, filtering out owners.
        
        Returns:
            List of team members (excluding free-owner and owner roles)
        """
        try:
            all_members = self.get_all_members()
            
            # Filter out owners and free-owners
            team_members = [
                member for member in all_members 
                if member.get('role') not in ['free-owner', 'owner']
            ]
            
            logging.info(f"Found {len(all_members)} total members, {len(team_members)} non-owner members")
            
            return team_members
            
        except requests.exceptions.RequestException as e:
            logging.error(f"Failed to fetch team members: {e}")
            return []
    
    def remove_user_from_team(self, user_email: str) -> bool:
        """
        Remove a user from the team (Note: This would require additional API endpoints
        that may not be available in the current Cursor Admin API).
        
        Args:
            user_email: Email of the user to remove
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Note: The current Cursor Admin API doesn't provide user removal endpoints
            # This would need to be done through the Cursor dashboard or other means
            logging.warning(f"User removal not supported via API. User {user_email} would need manual removal from dashboard.")
            return False
            
        except Exception as e:
            logging.error(f"Failed to remove user {user_email}: {e}")
            return False

class UserActivityAnalyzer:
    """Analyzes user activity patterns and identifies inactive users."""
    
    def __init__(self, config: Dict):
        self.config = config
        self.inactive_threshold = config.get('inactive_threshold', 14)
        self.exclude_weekends = config.get('exclude_weekends', True)
        self.excluded_dates = self._parse_excluded_dates(config.get('excluded_dates', []))
    
    def _parse_excluded_dates(self, date_strings: List[str]) -> List[datetime]:
        """Parse excluded date strings into datetime objects."""
        excluded_dates = []
        for date_str in date_strings:
            try:
                excluded_dates.append(datetime.strptime(date_str, '%Y-%m-%d'))
            except ValueError:
                logging.warning(f"Invalid date format: {date_str}")
        return excluded_dates
    
    def _count_business_days_backwards(self, end_date: datetime, target_business_days: int) -> datetime:
        """
        Count backwards from end_date until we reach the target number of business days.
        Excludes weekends and holidays.
        
        Args:
            end_date: The end date to count backwards from
            target_business_days: Number of business days to count back
            
        Returns:
            The start date that gives us target_business_days of business days
        """
        current_date = end_date
        business_days_counted = 0
        
        while business_days_counted < target_business_days:
            # Check if current date is a business day
            is_weekend = current_date.weekday() >= 5
            is_holiday = current_date.date() in [d.date() for d in self.excluded_dates]
            
            if not is_weekend and not is_holiday:
                business_days_counted += 1
            
            # Move to previous day
            current_date -= timedelta(days=1)
        
        return current_date
    
    def analyze_activity(self, activity_data: List[Dict], analysis_start_date: datetime = None) -> Dict:
        """
        Analyze user activity data to identify inactive users.
        
        Args:
            activity_data: List of user activity records from API
            analysis_start_date: Start date of the analysis period (for users never active)
            
        Returns:
            Analysis results including inactive users and statistics
        """
        if not activity_data:
            return {'inactive_users': [], 'user_reports': [], 'summary': {}}
        
        # Convert to DataFrame for easier processing
        df = pd.DataFrame(activity_data)
        
        # Ensure required columns exist
        required_columns = ['date', 'user_id', 'user_email', 'is_active']
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            logging.error(f"Missing required columns: {missing_columns}")
            return {'inactive_users': [], 'user_reports': [], 'summary': {}}
        
        # Convert date column
        df['date'] = pd.to_datetime(df['date'])
        df = df.sort_values(['user_email', 'date'])
        
        # Check for Unix epoch dates (users who have never been active)
        epoch_dates = df[df['date'].dt.year == 1970]
        if not epoch_dates.empty:
            logging.info(f"Found {len(epoch_dates)} records with Unix epoch dates (1970). These users have never been active.")
        
        inactive_users = []
        user_reports = []
        
        for email in df['user_email'].unique():
            user_data = df[df['user_email'] == email].copy()
            
            # Debug: Check if this is j.brannum
            if email == 'j.brannum@slingshotaerospace.com':
                logging.info(f"DEBUG: Analyzing j.brannum data")
                logging.info(f"DEBUG: Total records: {len(user_data)}")
                logging.info(f"DEBUG: Date range: {user_data['date'].min()} to {user_data['date'].max()}")
                logging.info(f"DEBUG: Active records: {len(user_data[user_data['is_active'] == True])}")
                logging.info(f"DEBUG: Inactive records: {len(user_data[user_data['is_active'] == False])}")
                
                # Check specifically for August 19
                aug19_data = user_data[user_data['date'].dt.date == datetime(2025, 8, 19).date()]
                if not aug19_data.empty:
                    logging.info(f"DEBUG: August 19 data found: {aug19_data.iloc[0].to_dict()}")
                else:
                    logging.info(f"DEBUG: No August 19 data found for j.brannum")
            
            # Check if this user has Unix epoch dates (never been active)
            has_epoch_dates = (user_data['date'].dt.year == 1970).any()
            
            consecutive_inactive_days = 0
            max_consecutive_inactive = 0
            inactive_start_date = None
            last_active_date = None
            
            total_days = len(user_data)
            active_days = len(user_data[user_data['is_active'] == True])
            inactive_days = total_days - active_days
            
            for _, row in user_data.iterrows():
                current_date = row['date']
                is_active = row['is_active']
                
                # Check if date should be excluded (weekends and holidays)
                is_excluded = False
                
                if current_date.date() in [d.date() for d in self.excluded_dates]:
                    is_excluded = True
                
                if self.exclude_weekends and current_date.weekday() >= 5:
                    is_excluded = True
                
                # Skip excluded days entirely - they don't count toward inactivity
                if is_excluded:
                    continue
                
                # This is a business day - count it toward inactivity
                if is_active:
                    consecutive_inactive_days = 0
                    inactive_start_date = None
                    last_active_date = current_date
                else:
                    if consecutive_inactive_days == 0:
                        inactive_start_date = current_date
                    consecutive_inactive_days += 1
                    max_consecutive_inactive = max(max_consecutive_inactive, consecutive_inactive_days)
            
            # Create user report
            user_report = {
                'email': email,
                'user_id': user_data['user_id'].iloc[0],
                'total_days': total_days,
                'active_days': active_days,
                'inactive_days': inactive_days,
                'current_consecutive_inactive': consecutive_inactive_days,
                'max_consecutive_inactive': max_consecutive_inactive,
                'activity_rate': f"{(active_days/total_days)*100:.1f}%" if total_days > 0 else "0%",
                'last_active_date': last_active_date.strftime('%Y-%m-%d') if last_active_date else 'Never'
            }
            user_reports.append(user_report)
            
            # Check if user meets inactive threshold
            if consecutive_inactive_days >= self.inactive_threshold:
                # Handle case where user has never been active (Unix epoch dates)
                if has_epoch_dates:
                    # User has never been active - use the start of analysis period
                    inactive_since = analysis_start_date.strftime('%Y-%m-%d') if analysis_start_date else 'Unknown'
                elif inactive_start_date is None and last_active_date is None:
                    # User has never been active - use the start of analysis period
                    inactive_since = analysis_start_date.strftime('%Y-%m-%d') if analysis_start_date else 'Unknown'
                else:
                    inactive_since = inactive_start_date.strftime('%Y-%m-%d') if inactive_start_date else 'Unknown'
                

                inactive_users.append({
                    'email': email,
                    'user_id': user_data['user_id'].iloc[0],
                    'consecutive_inactive_days': consecutive_inactive_days,
                    'inactive_since': inactive_since,
                    'last_active_date': last_active_date.strftime('%Y-%m-%d') if last_active_date else 'Never'
                })
        
        return {
            'inactive_users': inactive_users,
            'user_reports': user_reports,
            'summary': {
                'total_users': len(user_reports),
                'inactive_threshold': self.inactive_threshold,
                'inactive_users_count': len(inactive_users)
            }
        }


class AuditLogger:
    """Handles audit logging for compliance and tracking."""
    
    def __init__(self, log_file: str = "user_management_audit.log"):
        self.log_file = log_file
        
        # Create a custom formatter with more detailed information
        formatter = logging.Formatter(
            '%(asctime)s | %(levelname)-8s | %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        
        # File handler for persistent logging
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(formatter)
        
        # Console handler for immediate feedback
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)
        
        # Configure root logger
        logging.basicConfig(
            level=logging.INFO,
            handlers=[file_handler, console_handler]
        )
        
        # Log initialization
        logging.info("=" * 80)
        logging.info("AUTOMATED USER MANAGEMENT SESSION STARTED")
        logging.info(f"Log file: {os.path.abspath(log_file)}")
        logging.info("=" * 80)
    
    def log_action(self, action: str, user_email: str, group_name: str, 
                   details: str = "", dry_run: bool = False) -> None:
        """Log a user management action."""
        status = "DRY_RUN" if dry_run else "EXECUTED"
        message = f"{status} | {action} | User: {user_email} | Group: {group_name}"
        if details:
            message += f" | Details: {details}"
        
        logging.info(message)
        
        # Also log to a separate actions file for easy review
        actions_log_file = "user_actions.log"
        with open(actions_log_file, 'a') as f:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            f.write(f"{timestamp} | {status} | {action} | {user_email} | {group_name} | {details}\n")
    
    def log_analysis(self, analysis_results: Dict) -> None:
        """Log analysis results."""
        summary = analysis_results.get('summary', {})
        inactive_count = len(analysis_results.get('inactive_users', []))
        
        logging.info("=" * 60)
        logging.info("ANALYSIS RESULTS")
        logging.info("=" * 60)
        logging.info(f"Total users analyzed: {summary.get('total_users', 0)}")
        logging.info(f"Inactive threshold: {summary.get('inactive_threshold', 0)} days")
        logging.info(f"Users meeting threshold: {inactive_count}")
        
        # Log details about inactive users
        inactive_users = analysis_results.get('inactive_users', [])
        if inactive_users:
            logging.info("INACTIVE USERS DETAILS:")
            for user in inactive_users:
                logging.info(f"  • {user['email']}: {user['consecutive_inactive_days']} days inactive")
                logging.info(f"    └─ Last active: {user['last_active_date']}")
                logging.info(f"    └─ Inactive since: {user['inactive_since']}")
        else:
            logging.info("No users found meeting the inactivity threshold")
        
        logging.info("=" * 60)

class AutomatedUserManager:
    """Main class for automated user management."""
    
    def __init__(self, config_file: str):
        self.config = self._load_config(config_file)
        self.cursor_client = CursorAPIClient(
            api_key=self.config['cursor_api']['api_key'],
            base_url=self.config['cursor_api'].get('base_url', 'https://api.cursor.com')
        )
        self.analyzer = UserActivityAnalyzer(self.config)
        self.audit_logger = AuditLogger(self.config.get('audit_log_file', 'user_management_audit.log'))
    
    def _load_config(self, config_file: str) -> Dict:
        """Load configuration from YAML file."""
        try:
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            logging.error(f"Failed to load config file: {e}")
            sys.exit(1)
    
    def run_analysis(self, dry_run: bool = False) -> Tuple[Dict, List[Dict]]:
        """
        Run the complete user inactivity analysis and management process.
        
        Args:
            dry_run: If True, don't actually remove users, just simulate
            
        Returns:
            Tuple of (analysis_results, actions_taken)
        """
        logging.info("Starting automated user management process")
        
        # Calculate date range for analysis - use business day counting
        end_date = datetime.now()
        analysis_days = self.config.get('analysis_days', 35)
        inactive_threshold = self.config.get('inactive_threshold', 14)
        
        # Calculate start date by counting backwards business days
        # We want to look back enough to capture activity history, but count business days for threshold
        start_date = self.analyzer._count_business_days_backwards(end_date, analysis_days)
        
        # Fetch team members (excluding owners)
        logging.info("Fetching team members (excluding owners)")
        team_members = self.cursor_client.get_team_members()
        team_member_emails = {member.get('email') for member in team_members}
        
        logging.info(f"Found {len(team_member_emails)} team members to analyze")
        
        # Fetch user activity data
        logging.info(f"Fetching user activity data from {start_date.date()} to {end_date.date()}")
        logging.info(f"Analysis period: {analysis_days} business days back from current date")
        activity_data = self.cursor_client.get_user_activity(start_date, end_date)
        
        if not activity_data:
            logging.error("No activity data received from API")
            return {}, []
        
        # Filter activity data to only include team members (not owners)
        filtered_activity_data = [
            record for record in activity_data 
            if record.get('user_email') in team_member_emails
        ]
        
        logging.info(f"Filtered activity data: {len(activity_data)} total records, {len(filtered_activity_data)} team member records")
        
        # Analyze activity (only for team members)
        analysis_results = self.analyzer.analyze_activity(filtered_activity_data, start_date)
        self.audit_logger.log_analysis(analysis_results)
        
        # Process inactive users
        actions_taken = []
        inactive_users = analysis_results.get('inactive_users', [])
        
        for user in inactive_users:
            # User is already confirmed to be a team member (not owner) from earlier filtering
                action = {
                    'action': 'FLAG_FOR_REMOVAL',
                    'user_email': user['email'],
                    'user_id': user['user_id'],
                    'group_name': 'Cursor Team',
                    'reason': f"Inactive for {user['consecutive_inactive_days']} days"
                }
                
                if not dry_run:
                    success = self.cursor_client.remove_user_from_team(user['email'])
                    if success:
                        actions_taken.append(action)
                        self.audit_logger.log_action(
                            action['action'], user['email'], 'Cursor Team',
                            f"Inactive for {user['consecutive_inactive_days']} days"
                        )
                    else:
                        # Log that manual removal is needed
                        actions_taken.append(action)
                        self.audit_logger.log_action(
                            'MANUAL_REMOVAL_REQUIRED', user['email'], 'Cursor Team',
                            f"Inactive for {user['consecutive_inactive_days']} days - Remove via dashboard"
                        )
                else:
                    actions_taken.append(action)
                    self.audit_logger.log_action(
                        action['action'], user['email'], 'Cursor Team',
                        f"Inactive for {user['consecutive_inactive_days']} days", dry_run=True
                    )
        
        
        logging.info(f"Process completed. Actions taken: {len(actions_taken)}")
        
        # Log session completion
        logging.info("=" * 80)
        logging.info("AUTOMATED USER MANAGEMENT SESSION COMPLETED")
        logging.info("=" * 80)
        
        return analysis_results, actions_taken

def main():
    """Main function."""
    parser = argparse.ArgumentParser(description='Automated User Management with Cursor API')
    parser.add_argument('--config', default='config.yaml', help='Configuration file path')
    parser.add_argument('--dry-run', action='store_true', help='Run in dry-run mode (no actual changes)')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.config):
        print(f"Error: Configuration file '{args.config}' not found.")
        print("Please create a config.yaml file with your settings.")
        sys.exit(1)
    
    manager = AutomatedUserManager(args.config)
    
    try:
        analysis_results, actions_taken = manager.run_analysis(dry_run=args.dry_run)
        
        # Print summary
        print("\n" + "="*60)
        print("AUTOMATED USER MANAGEMENT SUMMARY")
        print("="*60)
        
        summary = analysis_results.get('summary', {})
        print(f"Total Users Analyzed: {summary.get('total_users', 0)}")
        print(f"Inactive Users Found: {len(analysis_results.get('inactive_users', []))}")
        print(f"Actions Taken: {len(actions_taken)}")
        
        if args.dry_run:
            print("\nDRY RUN MODE - No actual changes were made")
        
        if actions_taken:
            print("\n🚨 USERS FLAGGED FOR REMOVAL:")
            print("-" * 50)
            for action in actions_taken:
                print(f"• {action['user_email']}")
                print(f"  └─ Reason: {action['reason']}")
                print(f"  └─ Action: {action['action']}")
                print()
            
            print("📋 MANUAL ACTIONS REQUIRED:")
            print("-" * 50)
            print("1. Log into Cursor Dashboard: https://cursor.com/dashboard")
            print("2. Go to Settings → Team Members")
            print("3. Remove the flagged users listed above")
            print("4. Consider reaching out to users before removal")
            print()
        
        # Show logging information
        print("\n📊 LOGGING INFORMATION:")
        print("-" * 50)
        print(f"• Main log file: user_management_audit.log")
        print(f"• Actions log file: user_actions.log")
        print(f"• Log location: {os.path.abspath('.')}")
        print("• Check logs for detailed analysis and action history")
        print()
        
    except KeyboardInterrupt:
        print("\nProcess interrupted by user")
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
