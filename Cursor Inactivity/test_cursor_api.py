#!/usr/bin/env python3
"""
Test script for Cursor Admin API integration
"""

import requests
import json
from datetime import datetime, timedelta

def test_cursor_api():
    """Test the Cursor Admin API endpoints."""
    
    # API Configuration
    api_key = "key_bb8698ea71c06e58baf1e7a26aa8eed288a8b38640d9879896f9eedda6d39955"
    base_url = "https://api.cursor.com"
    
    # Set up session with authentication
    session = requests.Session()
    session.auth = (api_key, '')
    session.headers.update({'Content-Type': 'application/json'})
    
    print("Testing Cursor Admin API Integration")
    print("=" * 50)
    
    # Test 1: Get Team Members
    print("\n1. Testing GET /teams/members")
    try:
        response = session.get(f"{base_url}/teams/members")
        response.raise_for_status()
        data = response.json()
        
        team_members = data.get('teamMembers', [])
        print(f"✅ Success! Found {len(team_members)} team members")
        
        # Show first few members
        for i, member in enumerate(team_members[:3]):
            print(f"   - {member['name']} ({member['email']}) - {member['role']}")
        
        if len(team_members) > 3:
            print(f"   ... and {len(team_members) - 3} more members")
            
    except Exception as e:
        print(f"❌ Failed to get team members: {e}")
    
    # Test 2: Get Daily Usage Data
    print("\n2. Testing POST /teams/daily-usage-data")
    try:
        # Test with recent date range (last 7 days)
        end_date = datetime.now()
        start_date = end_date - timedelta(days=7)
        
        start_epoch = int(start_date.timestamp() * 1000)
        end_epoch = int(end_date.timestamp() * 1000)
        
        payload = {
            'startDate': start_epoch,
            'endDate': end_epoch
        }
        
        response = session.post(f"{base_url}/teams/daily-usage-data", json=payload)
        response.raise_for_status()
        data = response.json()
        
        usage_data = data.get('data', [])
        print(f"✅ Success! Retrieved {len(usage_data)} usage records")
        
        if usage_data:
            # Show sample data
            sample = usage_data[0]
            print(f"   Sample record:")
            print(f"     - Date: {datetime.fromtimestamp(sample['date']/1000).strftime('%Y-%m-%d')}")
            print(f"     - Email: {sample.get('email', 'N/A')}")
            print(f"     - Active: {sample.get('isActive', 'N/A')}")
            print(f"     - Lines Added: {sample.get('totalLinesAdded', 0)}")
            print(f"     - Chat Requests: {sample.get('chatRequests', 0)}")
        else:
            print("   No usage data found for the specified date range")
            
    except Exception as e:
        print(f"❌ Failed to get daily usage data: {e}")
    
    # Test 3: Test data transformation
    print("\n3. Testing data transformation")
    try:
        # Simulate the transformation logic from the main script
        if usage_data:
            transformed_data = []
            for record in usage_data:
                if 'email' in record and 'isActive' in record:
                    transformed_data.append({
                        'date': record['date'],
                        'user_id': record.get('email', ''),
                        'user_email': record['email'],
                        'is_active': record['isActive']
                    })
            
            print(f"✅ Successfully transformed {len(transformed_data)} records")
            if transformed_data:
                sample = transformed_data[0]
                print(f"   Sample transformed record:")
                print(f"     - Date: {datetime.fromtimestamp(sample['date']/1000).strftime('%Y-%m-%d')}")
                print(f"     - Email: {sample['user_email']}")
                print(f"     - Active: {sample['is_active']}")
        else:
            print("   No data to transform")
            
    except Exception as e:
        print(f"❌ Failed to transform data: {e}")
    
    print("\n" + "=" * 50)
    print("API Test Complete!")
    print("\nNext steps:")
    print("1. Run the automated script with --dry-run to test the full workflow")
    print("2. Check the audit log for detailed information")
    print("3. Configure email notifications if needed")

if __name__ == "__main__":
    test_cursor_api()
