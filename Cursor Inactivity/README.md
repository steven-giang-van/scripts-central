# User Inactivity Analysis Tool

A Python script for analyzing user activity data to identify users who have been inactive for extended periods, with smart exclusion of weekends and holidays.

## Features

- **🎯 Configurable Thresholds**: Set custom inactive day thresholds (default: 14 days)
- **📅 Smart Date Exclusion**: Automatically excludes weekends from consecutive inactive counting
- **🎉 Holiday Support**: Manually exclude specific holidays from analysis
- **🔄 Counter Reset Logic**: Resets inactivity counters when users are active on excluded dates
- **📊 Comprehensive Reporting**: Detailed reports with activity rates and last active dates
- **💻 Flexible Input**: Supports different CSV files via command line

## Requirements

- Python 3.6+
- pandas library

## Installation

1. Clone this repository:
```bash
git clone <your-repo-url>
cd user-inactivity-analysis
```

2. Install required dependencies:
```bash
pip3 install pandas
```

## Usage

### Basic Usage
```bash
python3 analyze_user_inactivity.py
```

### With Custom CSV File
```bash
python3 analyze_user_inactivity.py your_data.csv
```

## CSV File Format

Your CSV file should contain the following columns:
- **Date**: Date in ISO format (e.g., `2025-07-01T00:00:00.000Z`)
- **Email**: User email address
- **Is Active**: Boolean field (`TRUE`/`FALSE`)

Example:
```csv
Date,Email,Is Active
2025-07-01T00:00:00.000Z,user@example.com,TRUE
2025-07-02T00:00:00.000Z,user@example.com,FALSE
```

## Configuration

### Modify Inactive Threshold
Change the `inactive_threshold` parameter in the `main()` function:
```python
results = analyze_user_inactivity(csv_file, excluded_holidays, inactive_threshold=21)  # 21 days instead of 14
```

### Add Holidays
Update the `excluded_holidays` list in the `main()` function:
```python
excluded_holidays = [
    datetime(2025, 7, 4),   # Independence Day
    datetime(2025, 12, 25), # Christmas
    datetime(2025, 1, 1),   # New Year's Day
]
```

### Disable Weekend Exclusion
Set `exclude_weekends=False` in the analysis call:
```python
results = analyze_user_inactivity(csv_file, excluded_holidays, inactive_threshold=14, exclude_weekends=False)
```

## Output

The script provides two levels of reporting:

### 1. Basic Report
- Users meeting the inactive threshold
- Summary statistics
- Exclusion information

### 2. Detailed Report (Optional)
- All users sorted by current consecutive inactive days
- Individual user statistics including:
  - Total days in dataset
  - Active vs inactive days
  - Activity rate percentage
  - Last active date
  - Current and maximum consecutive inactive periods

## Logic

### Date Exclusion Logic
1. **Weekends**: Automatically detected (Saturday & Sunday) and excluded from counting
2. **Holidays**: Manually specified dates excluded from counting
3. **Reset Behavior**: If a user is active on an excluded date, their inactivity counter resets to 0

### Consecutive Day Calculation
- Only counts business days (Monday-Friday) unless weekends are included
- Excludes specified holidays
- Resets when user becomes active on any day (including excluded dates)

## Example Output

```
User Inactivity Analysis Results
============================================================
Excluded from counting: weekends, holidays (07/04)
Looking for users inactive for 14+ consecutive days...
------------------------------------------------------------

No users found with 14+ consecutive inactive days.

Summary Statistics:
Total users: 30
Users with any activity: 26
Average activity rate: 39.8%
Users inactive for 14+ days: 0
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is open source and available under the [MIT License](LICENSE).

## Support

For questions or issues, please open an issue in the GitHub repository. 
