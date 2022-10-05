--====================================================================================================================================================================================================--
-- SPC CHARTS SQL QUERY v2.4
--====================================================================================================================================================================================================--
--
-- This SQL query is used to create statistical process control (SPC) charts
-- The chart types available are XmR (along with Pareto), T, and G
-- The output table can be used with the accompanying Power BI template to view the charts
-- The latest version of this, the accompanying tools, and the developer how-to guide can be found at: https://future.nhs.uk/MDC/view?objectId=28387280
--
-- The query is split into multiple steps:
--     • Step 1: This step is for initial setup
--     • Step 2: This step is for custom settings
--     • Step 3: This step is where the metric and raw data are inserted, and optionally baseline and target data too
--     • Step 4: This step is where the SPC calculations are performed, including special cause rules and icons
--     • Step 5: This step is where warnings are calculated and returned, if turned on
--     • Step 6: This step is where the SPC data is returned
--     • Step 7: This step is for clear-up
--
-- Steps 1, 4-5, and 7 are to be left as they are
-- Steps 2-3 are to be changed, and there is information at the beginning of these steps detailing what to change and which warnings are checked in Step 5
-- Step 6 only needs to be changed by storing the output in a table if the accompanying Power BI template is used and connected that way
--
-- At the end of each step, a message is printed so that progress can be monitored
-- At the end of the query, Column Index details all the columns used throughout the query
--
-- 'Partition' refers to where a chart is broken up by recalculation of limits or a baseline
-- Where no recalculation of limits is performed or baseline set, a chart has a single partition
--
-- This version has been tested on SQL Server 2012 and is not compatible with older versions (use SELECT @@VERSION to check your version)
-- Alternative versions that support older versions can be shared and found at: https://future.nhs.uk/MDC/view?objectId=30535408
--
-- For queries and feedback, please email england.improvementanalyticsteam@nhs.net and quote the name and version number
--
--====================================================================================================================================================================================================--
-- CHANGE LOG
--====================================================================================================================================================================================================--
--
-- VERSION    DATE          TESTED ON          AUTHOR            COMMENT
-- 2.0        27/07/2021    SQL Server 2012    Matthew Callus    Development of new version
-- 2.0.1      04/08/2021    SQL Server 2012    Matthew Callus    Replaced tabs with spaces and tidied up layout
--                                                               Corrected typos
-- 2.1        10/09/2021    SQL Server 2012    Matthew Callus    Added logic to remove moving range outliers from process limit calculations (default setting is off)
--                                                                   • Added @ExcludeMovingRangeOutliers
--                                                                   • Added [MovingRangeMeanForProcessLimits]
--                                                                   • Added [MovingRangeMeanWithoutOutliers]
--                                                               Updated [Target] to not return a value when [MetricImprovement] not 'Up' or 'Down'
--                                                                   • Added warning
--                                                               Updated logic for two-to-three sigma special cause rule, requiring third point to be on the same side of the mean
--                                                                   • Removed #SPCCalculationsSpecialCauseTwoThreeSigmaPartitionCount
--                                                                   • Removed [SpecialCauseTwoThreeSigmaAboveMeanPartitionCount]
--                                                                   • Removed [SpecialCauseTwoThreeSigmaBelowMeanPartitionCount]
--                                                               Updated [VariationIcon] to return value when [MetricImprovement] = 'Neither'
--                                                                   • Added [SpecialCauseNeitherHighFlag]
--                                                                   • Added [SpecialCauseNeitherLowFlag]
--                                                               Updated [AssuranceIcon] to be a pass/fail when the target is on a process limit
-- 2.2        17/11/2021    SQL Server 2012    Matthew Callus    Added columns and added to output
--                                                                   • Added [MetricFormat]
--                                                                   • Added [GhostValue]
--                                                               Replaced flag columns with value columns
--                                                                   • Replaced [MovingRangeHighPointFlag] with [MovingRangeHighPointValue]
--                                                                   • Replaced [SpecialCauseImprovementFlag] with [SpecialCauseImprovementValue]
--                                                                   • Replaced [SpecialCauseConcernFlag] with [SpecialCauseConcernValue]
--                                                                   • Replaced [SpecialCauseNeitherFlag] with [SpecialCauseNeitherValue]
--                                                               Renamed columns
--                                                                   • Renamed [GhostFlag] to [GhostFlag] and removed from output
--                                                                   • Renamed [MovingRange] to [MovingRangeWithPartition]
--                                                                   • Renamed [MovingRangeNoPartition] to [MovingRange]
--                                                               Updated logic for trend special cause rule, allowing for crossing of partitions
--                                                               Removed metric partition in hierarchy
--                                                               Added warning for baseline including special cause variation
--                                                               Improved performance in Step 4a, hierarchy
--                                                                   • Replaced DistinctGroups CTE with #SPCCalculationsDistinctGroups
--                                                               Improved performance in Step 5, warning
-- 2.2.1      24/11/2021    SQL Server 2012    Matthew Callus    Corrected label for 'Concern (High)' and 'Concern (Low)'
-- 2.2.2      14/12/2021    SQL Server 2012    Matthew Callus    Expanded Power BI instructions in Step 6 to include stored procedures
-- 2.3        15/03/2022    SQL Server 2012    Matthew Callus    Added T and G chart types
--                                                                   • Added columns and added to output
--                                                                         • Added [ChartType]
--                                                                               • Added warning when not 'XmR, 'T', or 'G'
--                                                                         • Added [PointRank]
--                                                                   • Added #SPCCalculationsDayDifference
--                                                                         • Added [DayDifference]
--                                                                   • Added #SPCCalculationsDayDifferenceTransformed
--                                                                         • Added [DayDifferenceTransformed]
--                                                                   • Added #SPCCalculationsDayDifferenceTransformedMean
--                                                                         • Added [DayDifferenceTransformedMean]
--                                                                   • Added #SPCCalculationsDayDifferenceTransformedMovingRangeMean
--                                                                         • Added [DayDifferenceTransformedMovingRangeMean]
--                                                                   • Added additional columns
--                                                                         • Added [DayDifferenceTransformedMovingRange]
--                                                                         • Added [PartitionDayDifferenceTransformedMovingRangeMean]
--                                                                         • Added [PartitionDayDifferenceTransformedMean]
--                                                                   • Updated columns
--                                                                         • Updated [RowID]
--                                                                         • Updated [PointRank]
--                                                                         • Updated [Mean]
--                                                                         • Updated [UpperProcessLimit]
--                                                                         • Updated [UpperTwoSigma]
--                                                                         • Updated [UpperOneSigma]
--                                                                         • Updated [LowerOneSigma]
--                                                                         • Updated [LowerTwoSigma]
--                                                                         • Updated [LowerProcessLimit]
--                                                               Updated inputs
--                                                                   • Updated [MetricConflictRule] requirement for XmR charts only
--                                                                   • Added warning when [MetricFormat] is not set to 'General' when [ChartType] is 'T' or 'G'
--                                                                   • Added warning when [MetricFormat] is not a valid option
--                                                                   • Changed [Value] to accept NULLs
--                                                                         • Added warning for NULLs when [ChartType] is 'XmR' or 'G'
--                                                                         • Added warning when provided and [ChartType] is 'T'
--                                                                   • Added warning when [LowMeanWarningValue] is provided and [ChartType] is 'T' or 'G'
--                                                                   • Added warning when [GhostFlag] = '1' and [ChartType] is 'T' or 'G'
--                                                                   • Updated [Target] to not return a value when [ChartType] is 'T' or 'G'
--                                                                         • Added warning
--                                                               Updated outputs
--                                                                   • Updated [MovingRange] and [MovingRangeWithPartition] to not return a value when [ChartType] is 'T' or 'G'
--                                                                         • Other moving range columns are left empty as a result
--                                                                   • Updated [AssuranceIcon] to not return a value when [ChartType] is 'T' or 'G'
--                                                               Improved performance in Step 5, warning
-- 2.3.1      04/05/2022    SQL Server 2012    Matthew Callus    Corrected [LowerOneSigma] and [LowerTwoSigma] for T charts
-- 2.4        11/08/2022    SQL Server 2012    Matthew Callus    Added filters
--                                                                   • Renamed [ChartID] to [IconID]
--                                                                   • Updated columns
--                                                                         • Updated [RowID]
--                                                                         • Updated [IconID]
--                                                                   • Added columns and added to output
--                                                                         • Added [Filter1]
--                                                                         • Added [Filter2]
--                                                                         • Added [ChartID] (new version)
--                                                                   • Replaced [Metric] and [Group] partition with [ChartID] (new version)
--                                                                   • Added filters to existing warning
--                                                                   • Added warnings
--                                                                         • Added warning when [Filter1] is '< No Filter >'
--                                                                         • Added warning when [Filter2] is '< No Filter >'
--                                                               Added vertical axis minimum and maximum
--                                                                   • Added columns and added to output
--                                                                         • Added [VerticalAxisMinFix]
--                                                                         • Added [VerticalAxisMinFlex]
--                                                                         • Added [VerticalAxisMaxFix]
--                                                                         • Added [VerticalAxisMaxFlex]
--                                                                   • Added warnings
--                                                                         • Added warning when [VerticalAxisMinFix] and [VerticalAxisMinFlex] are both provided
--                                                                         • Added warning when [VerticalAxisMaxFix] and [VerticalAxisMaxFlex] are both provided
--                                                                         • Added warning when [VerticalAxisMinFix] or [VerticalAxisMinFlex] is not less than [VerticalAxisMaxFix] or [VerticalAxisMaxFlex]
--                                                               Added date format
--                                                                   • Added [DateFormat] column and added to output
--                                                                   • Added warning when [DateFormat] is not a valid option
--                                                               Added option to order groups in hierarchy level
--                                                                   • Added [GroupHierarchyOrder]
--                                                                         • Added warning when multiple [GroupHierarchyOrder] values provided for same [Group]
--                                                               Made changes to allow for pareto charts
--                                                                   • Renamed [GroupIndent] to [GroupHierarchy]
--                                                                         • Updated [GroupHierarchy] and added to output
--                                                                   • Updated [GroupName]
--                                                               Added additional warnings:
--                                                                   • Added warning for '||' delimiter inclusion in [MetricID], [Group], [Filter1], and [Filter2] concatenation
--                                                                   • Added warning when [Date] is duplicated with [DateFormat] selected
--                                                               Updated warnings:
--                                                                   • Added minimum point check to improvement/concern conflict affecting point warning
--                                                                   • Added minimum point check to improvement/concern conflict affecting variation icon warning
--                                                               Updated logic to remove moving range outliers from mean calculation
--                                                                   • Added [MeanWithoutOutliers]
--                                                               Removed 'NHS ENGLAND AND NHS IMPROVEMENT' name
--                                                               Updated email address
--
--====================================================================================================================================================================================================--
-- STEP 1: SETUP
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step prepares the messages that display during execution and removes the temporary tables that will be used if they already exist
--
--====================================================================================================================================================================================================--

-- Prevent every row inserted returning a message
SET NOCOUNT ON

-- Remove temporary tables if they already exist
IF OBJECT_ID('tempdb..#MetricData')                                             IS NOT NULL DROP TABLE #MetricData
IF OBJECT_ID('tempdb..#RawData')                                                IS NOT NULL DROP TABLE #RawData
IF OBJECT_ID('tempdb..#BaselineData')                                           IS NOT NULL DROP TABLE #BaselineData
IF OBJECT_ID('tempdb..#TargetData')                                             IS NOT NULL DROP TABLE #TargetData
IF OBJECT_ID('tempdb..#SPCCalculationsDistinctGroups')                          IS NOT NULL DROP TABLE #SPCCalculationsDistinctGroups
IF OBJECT_ID('tempdb..#SPCCalculationsHierarchy')                               IS NOT NULL DROP TABLE #SPCCalculationsHierarchy
IF OBJECT_ID('tempdb..#SPCCalculationsPartition')                               IS NOT NULL DROP TABLE #SPCCalculationsPartition
IF OBJECT_ID('tempdb..#SPCCalculationsBaselineFlag')                            IS NOT NULL DROP TABLE #SPCCalculationsBaselineFlag
IF OBJECT_ID('tempdb..#SPCCalculationsBaseline')                                IS NOT NULL DROP TABLE #SPCCalculationsBaseline
IF OBJECT_ID('tempdb..#SPCCalculationsAllTargets')                              IS NOT NULL DROP TABLE #SPCCalculationsAllTargets
IF OBJECT_ID('tempdb..#SPCCalculationsSingleTarget')                            IS NOT NULL DROP TABLE #SPCCalculationsSingleTarget
IF OBJECT_ID('tempdb..#SPCCalculationsDayDifference')                           IS NOT NULL DROP TABLE #SPCCalculationsDayDifference
IF OBJECT_ID('tempdb..#SPCCalculationsDayDifferenceTransformed')                IS NOT NULL DROP TABLE #SPCCalculationsDayDifferenceTransformed
IF OBJECT_ID('tempdb..#SPCCalculationsDayDifferenceTransformedMean')            IS NOT NULL DROP TABLE #SPCCalculationsDayDifferenceTransformedMean
IF OBJECT_ID('tempdb..#SPCCalculationsMean')                                    IS NOT NULL DROP TABLE #SPCCalculationsMean
IF OBJECT_ID('tempdb..#SPCCalculationsMovingRange')                             IS NOT NULL DROP TABLE #SPCCalculationsMovingRange
IF OBJECT_ID('tempdb..#SPCCalculationsMovingRangeMean')                         IS NOT NULL DROP TABLE #SPCCalculationsMovingRangeMean
IF OBJECT_ID('tempdb..#SPCCalculationsDayDifferenceTransformedMovingRangeMean') IS NOT NULL DROP TABLE #SPCCalculationsDayDifferenceTransformedMovingRangeMean
IF OBJECT_ID('tempdb..#SPCCalculationsMovingRangeProcessLimit')                 IS NOT NULL DROP TABLE #SPCCalculationsMovingRangeProcessLimit
IF OBJECT_ID('tempdb..#SPCCalculationsProcessLimits')                           IS NOT NULL DROP TABLE #SPCCalculationsProcessLimits
IF OBJECT_ID('tempdb..#SPCCalculationsBaselineLimits')                          IS NOT NULL DROP TABLE #SPCCalculationsBaselineLimits
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseSinglePoint')                 IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseSinglePoint
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseShiftPrep')                   IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseShiftPrep
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseShiftPartitionCount')         IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseShiftPartitionCount
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseShiftStartFlag')              IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseShiftStartFlag
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseShiftStartFlagCount')         IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseShiftStartFlagCount
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseShift')                       IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseShift
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTrendPrep')                   IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTrendPrep
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTrendPartitionCount')         IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTrendPartitionCount
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTrendStartFlag')              IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTrendStartFlag
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTrendStartFlagCount')         IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTrendStartFlagCount
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTrend')                       IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTrend
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTwoThreeSigmaPrep')           IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTwoThreeSigmaPrep
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTwoThreeSigmaStartFlag')      IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTwoThreeSigmaStartFlag
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTwoThreeSigmaStartFlagCount') IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTwoThreeSigmaStartFlagCount
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTwoThreeSigma')               IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTwoThreeSigma
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseCombined')                    IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseCombined
IF OBJECT_ID('tempdb..#SPCCalculationsIcons')                                   IS NOT NULL DROP TABLE #SPCCalculationsIcons
IF OBJECT_ID('tempdb..#SPCCalculationsRowCount')                                IS NOT NULL DROP TABLE #SPCCalculationsRowCount
IF OBJECT_ID('tempdb..#Warnings')                                               IS NOT NULL DROP TABLE #Warnings

-- Prepare variable for messages printed at the end of each step
DECLARE @PrintMessage NVARCHAR(MAX)

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 1  complete, setup'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 2A: SETTINGS: SPECIAL CAUSE
--====================================================================================================================================================================================================--
--
-- This step is where settings that determine how the process limits and special cause rules are calculated in Step 4 can be changed
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • @SettingSpecialCauseShiftPoints is not between 6 and 8 (inclusive)
--     • @SettingSpecialCauseTrendPoints is not between 6 and 8 (inclusive)
--
--====================================================================================================================================================================================================--

-- Removes moving range outliers from the calculation of the mean and process limits in XmR charts
-- ('1' = on | '0' = off)
DECLARE @ExcludeMovingRangeOutliers BIT = 0

-- The number of non-ghosted points in a row within metric/group/partition combination all above or all below the mean to trigger the special cause rule of a shift
DECLARE @SettingSpecialCauseShiftPoints INT = 7

-- The number of non-ghosted points in a row within metric/group/partition combination either all increasing or all decreasing, including endpoints, to trigger the special cause rule of a trend
DECLARE @SettingSpecialCauseTrendPoints INT = 7

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 2a complete, settings: special cause'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 2B: SETTINGS: OTHER
--====================================================================================================================================================================================================--
--
-- This step is where various other settings can be changed, most of which are checked in Step 5
--
-- Warnings will be displayed, if turned on (first setting below) and:
--     • A chart has an insufficient number of points (set with @SettingMinimumPoints) and @SettingMinimumPointsWarning is turned on
--     • A partition in a chart has an insufficient number of points (set with @SettingMinimumPointsPartition)
--     • A partition in a chart has too many points (set with @SettingMaximumPointsPartition)
--     • A chart has too many points to be displayed on a chart (set with @SettingMaximumPoints)
--     • A point triggers improvement and concern special cause rules and @SettingPointConflictWarning is turned on
--     • A variation icon uses a point that triggers improvement and concern special cause rules and @SettingVariationIconConflictWarning is turned on
--
--====================================================================================================================================================================================================--

-- Check for warnings and output the results
-- ('1' = on | '0' = off)
DECLARE @SettingGlobalWarnings BIT = 1

-- The minimum number of non-ghosted points needed for each chart (metric/group combination) to display as an SPC chart
-- Will otherwise display as a run chart, with SPC elements removed
-- Ignores recalculating of limits
-- (set to 2 for no minimum)
DECLARE @SettingMinimumPoints INT = 15

    -- Return warning
    -- ('1' = on | '0' = off)
    DECLARE @SettingMinimumPointsWarning BIT = 0

-- The minimum number of non-ghosted points needed for each step of a chart (metric/group/partition), including baselines
-- Ignored non-SPC charts
-- (set to 1 for no minimum)
DECLARE @SettingMinimumPointsPartition INT = 12

-- The maximum number of non-ghosted points allowed for each step of a chart (metric/group/partition), including baselines
-- (set to NULL for no maximum)
DECLARE @SettingMaximumPointsPartition INT = NULL

-- The maximum number of points the accompanying chart can accommodate
-- (set to NULL for no maximum)
DECLARE @SettingMaximumPoints INT = NULL

-- Return warning for non-ghosted points that trigger improvement and concern special cause rules
-- ('1' = on | '0' = off)
DECLARE @SettingPointConflictWarning BIT = 0

-- Return warning for variation icons that use a point that triggers improvement and concern special cause rules
-- ('1' = on | '0' = off)
DECLARE @SettingVariationIconConflictWarning BIT = 1

-- The number of spaces to indent each level of the group hierarchy
-- (Set to 0 for no indent)
DECLARE @SettingGroupHierarchyIndentSpaces INT = 4

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 2b complete, settings: other'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3A: METRIC DATA
--====================================================================================================================================================================================================--
--
-- This step is where the metric data is entered
--
-- The data must match the columns created in #MetricData
-- The data types can be changed, as detailed below, to reduce size
-- Additional columns can be added, which would then require their addition to Step 4b and Step 6.
--
-- [MetricOrder] is used to control the order the metrics appear in the dropdown; this is added automatically but could be manually controlled
-- [MetricID] and [MetricName] can be any value, even the same
-- [ChartType] can be either 'XmR', 'T', or 'G'
-- [MetricImprovement] can be either 'Up', 'Down', or 'Neither'
-- [MetricConflictRule] can be either 'Improvement' or 'Concern' and determines which to show when special cause rules for both are triggered; this must be provided when [ChartType] = 'XmR' and [MetricImprovement] is 'Up' or 'Down'
-- [DateFormat] can be either 'd/M/yy', 'd/M/yyyy', 'dd/MM/yy', 'dd/MM/yyyy', 'd MMM yy', 'd MMM yyyy', 'd MMMM yy', 'd MMMM yyyy', 'dd MMM yy', 'dd MMM yyyy', 'dd MMMM yy', 'dd MMMM yyyy', 'MMM yy', 'MMM yyyy', 'MMMM yy', 'MMMM yyyy', 'yyyy-MM', 'yyyy-MM-dd'
-- [MetricFormat] can be either 'General', 'Percentage', or Time
--     • Set as 'General' for T and G charts
--     • Time will display in decimal format in the accompanying Power BI template
-- [LowMeanWarningValue] can be specified to return a warning when the mean for any metric/group/filter/partition combination is less than the value; otherwise set as NULL
--     • Set as NULL for T and G charts
-- [ChartTitle], [HorizontalAxisTitle], and [VerticalAxisTitle] are used in the chart or can be set as NULL
-- [VerticalAxisMinFix] can be speficied to fix the vertical axis mininum to a specific value or [VerticalAxisMinFlex] can be specified to set a flexible minimum that cannot be be exceeded but is only used where necessary
--     • Set one or both to NULL; if both are provided, [VerticalAxisMinFix] is used in the accompany tools
-- [VerticalAxisMaxFix] can be speficied to fix the vertical axis maximum to a specific value or [VerticalAxisMaxFlex] can be specified to set a flexible maximum that cannot be be exceeded but is only used where necessary
--     • Set one or both to NULL; if both are provided, [VerticalAxisMaxFix] is used in the accompany tools
--
-- The data can be inserted into #MetricData one line at a time, as shown in the sample data below, or populated from a table or stored procedure (see examples in Step 3b)
-- The accompanying Excel file also contains a worksheet to generate INSERT lines
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [MetricOrder] is duplicated
--     • [MetricID] does not exist in #RawData (Step 3b)
--     • [MetricID] is duplicated
--     • [ChartType] is not a valid option
--     • [MetricImprovement] is not a valid option
--     • [MetricConflictRule] is not a valid option
--     • [DateFormat] is not a valid option
--     • [MetricFormat] is not a valid option
--     • [MetricFormat] not set to 'General' when [ChartType] is 'T' or 'G'
--     • [VerticalAxisMinFix] and [VerticalAxisMinFlex] are both provided
--     • [VerticalAxisMaxFix] and [VerticalAxisMaxFlex] are both provided
--     • [VerticalAxisMinFix] or [VerticalAxisMinFlex] is not less than [VerticalAxisMaxFix] or [VerticalAxisMaxFlex]
--     • [LowMeanWarningValue] is provided when [ChartType] is 'T' or 'G'
--     • The mean is less than [LowMeanWarningValue] in any partition
--
--====================================================================================================================================================================================================--

-- Create temporary table
CREATE TABLE #MetricData ( 
                           [MetricOrder]         INT             IDENTITY(1, 1) NOT NULL -- IDENTITY(1, 1) can be removed
                          ,[MetricID]            NVARCHAR(MAX)                  NOT NULL -- Can be reduced in size
                          ,[MetricName]          NVARCHAR(MAX)                  NOT NULL -- Can be reduced in size
                          ,[ChartType]           NVARCHAR(3)                    NOT NULL
                          ,[MetricImprovement]   NVARCHAR(7)                    NOT NULL
                          ,[MetricConflictRule]  NVARCHAR(11)                       NULL
                          ,[DateFormat]          NVARCHAR(10)                   NOT NULL
                          ,[MetricFormat]        NVARCHAR(10)                   NOT NULL
                          ,[LowMeanWarningValue] DECIMAL(38, 19)                    NULL -- Can be reduced in size
                          ,[ChartTitle]          NVARCHAR(MAX)                      NULL -- Can be reduced in size
                          ,[HorizontalAxisTitle] NVARCHAR(MAX)                      NULL -- Can be reduced in size
                          ,[VerticalAxisTitle]   NVARCHAR(MAX)                      NULL -- Can be reduced in size
                          ,[VerticalAxisMinFix]  DECIMAL(38, 19)                    NULL -- Can be reduced in size
                          ,[VerticalAxisMinFlex] DECIMAL(38, 19)                    NULL -- Can be reduced in size
                          ,[VerticalAxisMaxFix]  DECIMAL(38, 19)                    NULL -- Can be reduced in size
                          ,[VerticalAxisMaxFlex] DECIMAL(38, 19)                    NULL -- Can be reduced in size
                         )

-- Insert sample data for various metrics
INSERT INTO #MetricData VALUES ('M1', 'Rate'                             , 'XmR', 'Up'     , 'Concern', 'dd/MM/yy', 'Percentage', NULL, 'Rate'                             , 'Week Commencing', 'Compliance Rate'                   , NULL, 0   , NULL, 1   )
INSERT INTO #MetricData VALUES ('M2', 'Count (for improvement)'          , 'XmR', 'Down'   , 'Concern', 'MMM yy'  , 'General'   , 5   , 'Count (for improvement)'          , 'Month'          , 'Count of Incidents'                , NULL, 0   , NULL, NULL)
INSERT INTO #MetricData VALUES ('M3', 'Count (for monitoring)'           , 'XmR', 'Neither', NULL     , 'dd/MM/yy', 'General'   , 5   , 'Count (for monitoring)'           , NULL             , NULL                                , NULL, 0   , NULL, NULL)
INSERT INTO #MetricData VALUES ('M4', 'Time'                             , 'XmR', 'Neither', NULL     , 'dd/MM/yy', 'Time'      , NULL, NULL                               , 'Day'            , 'Time'                              , NULL, 0   , NULL, NULL)
INSERT INTO #MetricData VALUES ('M5', 'Days Between Events (XmR chart)'  , 'XmR', 'Up'     , 'Concern', 'dd/MM/yy', 'General'   , 5   , 'Days Between Events (XmR chart)'  , 'Event'          , 'Days Between Events'               , NULL, 0   , NULL, NULL)
INSERT INTO #MetricData VALUES ('M6', 'Days Between Events (T chart)'    , 'T'  , 'Up'     , NULL     , 'dd/MM/yy', 'General'   , NULL, 'Days Between Events (T chart)'    , 'Event'          , 'Days Between Events'               , 0   , NULL, NULL, NULL)
INSERT INTO #MetricData VALUES ('M7', 'Count (non-events between events)', 'G'  , 'Up'     , NULL     , 'dd/MM/yy', 'General'   , NULL, 'Count (non-events between events)', 'Event'          , 'Count of Non-Events Between Events', 0   , NULL, NULL, NULL)
INSERT INTO #MetricData VALUES ('M8', 'Pareto'                           , 'XmR', 'Up'     , 'Concern', 'MMM yy'  , 'General'   , 5   , 'Pareto'                           , 'Month'          , 'Count of Events'                   , NULL, 0   , NULL, NULL)

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3a complete, metric data'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3B: RAW DATA
--====================================================================================================================================================================================================--
--
-- This step is where the raw data is entered
--
-- The data must match the columns created in #RawData
-- The data types can be changed, as detailed below, to reduce size
-- Additional columns can be added, which would then require their addition to Step 4b and Step 6.
--
-- [MetricID] must match a row in #MetricData
-- [Group] may be the name of a team/ward/department etc.
-- [GroupParent] determines the hierarchy used in the dropdown and icon summary table; if specified, it must also exist as a group for any metric; otherwise set as NULL for the top level(s) or no hierarchy
-- [GroupHierarchyOrder] can be used to set the order of groups within a hierarchy; if not set or equal, alphabetical order is used; if set for some, those with NULL will be ordered first
-- [Filter1] and [Filter2] can be used to create multiple charts for each metric/group combination
--     • Set as NULL where not needed
--     • Do not use '< No Filter >'
-- [Date] must be unique for that metric/group/filter combination
-- [Value] must be a single value (i.e. post-calculation of any numerator and denominator); to enter times, enter the proportion of the day since midnight (e.g. 0.75 for 6pm)
--     • Set as NULL for T charts
-- [RecalculateLimitsFlag] can be either '1' (on) or '0' (off)
-- [GhostFlag] can be either '1' (on) or '0' (off)
--     • Set as '0' for T and G charts
-- [Annotation] can be any text; otherwise set as NULL
--
-- The data can be inserted into #RawData one line at a time, as shown in the sample data below, or populated from a table or stored procedure (see examples below)
-- The accompanying Excel file also contains a worksheet to generate INSERT lines
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [MetricID] does not exist in #MetricData (Step 3a)
--     • [GroupParent] is not provided as a group
--     • Multiple [GroupParent] are provided for same group
--     • Multiple [GroupHierarchyOrder] are provided for same group
--     • [MetricID], [Group], [Filter1], and [Filter2] concatenation includes '||' delimiter
--     • [Filter1] is '< No Filter >'
--     • [Filter2] is '< No Filter >'
--     • [Date] is duplicated for metric/group/filter combination
--     • [Date] is duplicated with [DateFormat] selected
--     • [Value] is not provided when [ChartType] is 'XmR' or 'G'
--     • [Value] is provided when [ChartType] is 'T'
--     • [RecalculateLimitsFlag] is not a valid option
--     • Recalculation of limits is within baseline (Step 3c)
--     • [GhostFlag] is not a valid option
--     • [GhostFlag] = 1 when [ChartType] is 'T' or 'G'
--
--====================================================================================================================================================================================================--

-- Create temporary table
CREATE TABLE #RawData (
                        [MetricID]              NVARCHAR(MAX)   NOT NULL -- Can be reduced in size
                       ,[Group]                 NVARCHAR(MAX)   NOT NULL -- Can be reduced in size
                       ,[GroupParent]           NVARCHAR(MAX)       NULL -- Can be reduced in size
                       ,[GroupHierarchyOrder]   INT                 NULL
                       ,[Filter1]               NVARCHAR(MAX)       NULL -- Can be reduced in size
                       ,[Filter2]               NVARCHAR(MAX)       NULL -- Can be reduced in size
                       ,[Date]                  DATE            NOT NULL
                       ,[Value]                 DECIMAL(38, 19)     NULL -- Can be reduced in size (might affect accuracy of calculations)
                       ,[RecalculateLimitsFlag] TINYINT         NOT NULL 
                       ,[GhostFlag]             TINYINT         NOT NULL
                       ,[Annotation]            NVARCHAR(MAX)       NULL -- Can be reduced in size
                      )

-- Insert sample data for various metrics and groups
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210104', 0.922, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210111', 0.928, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210118', 0.93 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210125', 0.926, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210201', 0.926, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210208', 0.923, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210215', 0.921, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210222', 0.918, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210301', 0.925, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210308', 0.91 , 0, 0, 'Below lower process limit')
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210315', 0.92 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210322', 0.924, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210329', 0.923, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210405', 0.92 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210412', 0.925, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210419', 0.928, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210426', 0.927, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210503', 0.921, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210510', 0.918, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210517', 0.921, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210524', 0.925, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210531', 0.939, 0, 0, 'Above upper process limit')
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210607', 0.929, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210614', 0.927, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210621', 0.925, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'TOTAL'       , NULL          , NULL, NULL, NULL, '20210628', 0.926, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210104', 0.972, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210111', 0.965, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210118', 0.966, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210125', 0.974, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210201', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210208', 0.971, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210215', 0.977, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210222', 0.97 , 0, 0, 'Start of seven points below mean')
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210301', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210308', 0.968, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210315', 0.965, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210322', 0.96 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210329', 0.967, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210405', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210412', 0.981, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210419', 0.977, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210426', 0.976, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210503', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210510', 0.973, 0, 0, 'Start of seven points above mean')
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210517', 0.975, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210524', 0.977, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210531', 0.98 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210607', 0.978, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210614', 0.98 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210621', 0.973, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department A', 'TOTAL'       , NULL, NULL, NULL, '20210628', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A1'     , 'Department A', NULL, NULL, NULL, '20210104', 0.972, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A1'     , 'Department A', NULL, NULL, NULL, '20210111', 0.965, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A1'     , 'Department A', NULL, NULL, NULL, '20210118', 0.966, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A1'     , 'Department A', NULL, NULL, NULL, '20210125', 0.974, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A1'     , 'Department A', NULL, NULL, NULL, '20210201', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A1'     , 'Department A', NULL, NULL, NULL, '20210208', 0.971, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A1'     , 'Department A', NULL, NULL, NULL, '20210215', 0.977, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A1'     , 'Department A', NULL, NULL, NULL, '20210222', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A2'     , 'Department A', NULL, NULL, NULL, '20210301', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A2'     , 'Department A', NULL, NULL, NULL, '20210308', 0.968, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A2'     , 'Department A', NULL, NULL, NULL, '20210315', 0.965, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A2'     , 'Department A', NULL, NULL, NULL, '20210322', 0.96 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A2'     , 'Department A', NULL, NULL, NULL, '20210329', 0.967, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A2'     , 'Department A', NULL, NULL, NULL, '20210405', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A2'     , 'Department A', NULL, NULL, NULL, '20210412', 0.981, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A3'     , 'Department A', NULL, NULL, NULL, '20210419', 0.977, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A3'     , 'Department A', NULL, NULL, NULL, '20210426', 0.976, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A3'     , 'Department A', NULL, NULL, NULL, '20210503', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A3'     , 'Department A', NULL, NULL, NULL, '20210510', 0.973, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A3'     , 'Department A', NULL, NULL, NULL, '20210517', 0.975, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A3'     , 'Department A', NULL, NULL, NULL, '20210524', 0.977, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A4'     , 'Department A', NULL, NULL, NULL, '20210531', 0.98 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A4'     , 'Department A', NULL, NULL, NULL, '20210607', 0.978, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A4'     , 'Department A', NULL, NULL, NULL, '20210614', 0.98 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A4'     , 'Department A', NULL, NULL, NULL, '20210621', 0.973, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area A4'     , 'Department A', NULL, NULL, NULL, '20210628', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210104', 0.965, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210111', 0.956, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210118', 0.963, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210125', 0.952, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210201', 0.947, 0, 0, 'Start of seven points increasing')
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210208', 0.951, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210215', 0.956, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210222', 0.958, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210301', 0.962, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210308', 0.965, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210315', 0.967, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210322', 0.961, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210329', 0.958, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210405', 0.947, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210412', 0.952, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210419', 0.963, 0, 0, 'Start of seven points decreasing')
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210426', 0.961, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210503', 0.96 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210510', 0.957, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210517', 0.956, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210524', 0.955, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210531', 0.952, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210607', 0.959, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210614', 0.963, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210621', 0.954, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department B', 'TOTAL'       , NULL, NULL, NULL, '20210628', 0.956, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B1'     , 'Department B', NULL, NULL, NULL, '20210104', 0.965, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B1'     , 'Department B', NULL, NULL, NULL, '20210111', 0.956, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B1'     , 'Department B', NULL, NULL, NULL, '20210118', 0.963, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B1'     , 'Department B', NULL, NULL, NULL, '20210125', 0.952, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B2'     , 'Department B', NULL, NULL, NULL, '20210201', 0.947, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B2'     , 'Department B', NULL, NULL, NULL, '20210208', 0.951, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B2'     , 'Department B', NULL, NULL, NULL, '20210215', 0.956, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B2'     , 'Department B', NULL, NULL, NULL, '20210222', 0.958, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B3'     , 'Department B', NULL, NULL, NULL, '20210301', 0.962, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B3'     , 'Department B', NULL, NULL, NULL, '20210308', 0.965, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B3'     , 'Department B', NULL, NULL, NULL, '20210315', 0.967, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B3'     , 'Department B', NULL, NULL, NULL, '20210322', 0.961, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B4'     , 'Department B', NULL, NULL, NULL, '20210329', 0.958, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B4'     , 'Department B', NULL, NULL, NULL, '20210405', 0.947, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B4'     , 'Department B', NULL, NULL, NULL, '20210412', 0.952, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B4'     , 'Department B', NULL, NULL, NULL, '20210419', 0.963, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B5'     , 'Department B', NULL, NULL, NULL, '20210426', 0.961, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B5'     , 'Department B', NULL, NULL, NULL, '20210503', 0.96 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B5'     , 'Department B', NULL, NULL, NULL, '20210510', 0.957, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B5'     , 'Department B', NULL, NULL, NULL, '20210517', 0.956, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B6'     , 'Department B', NULL, NULL, NULL, '20210524', 0.955, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B6'     , 'Department B', NULL, NULL, NULL, '20210531', 0.952, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B6'     , 'Department B', NULL, NULL, NULL, '20210607', 0.959, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B7'     , 'Department B', NULL, NULL, NULL, '20210614', 0.963, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B7'     , 'Department B', NULL, NULL, NULL, '20210621', 0.954, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area B7'     , 'Department B', NULL, NULL, NULL, '20210628', 0.956, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210104', 0.913, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210111', 0.911, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210118', 0.912, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210125', 0.909, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210201', 0.912, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210208', 0.923, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210215', 0.905, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210222', 0.923, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210301', 0.912, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210308', 0.905, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210315', 0.905, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210322', 0.898, 0, 0, 'Two out of three points within two-to-three sigma lines with the other point on the same side of the mean')
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210329', 0.901, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210405', 0.915, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210412', 0.91 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210419', 0.905, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210426', 0.912, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210503', 0.91 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210510', 0.907, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210517', 0.915, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210524', 0.912, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210531', 0.909, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210607', 0.92 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210614', 0.923, 0, 0, 'Three out of three points within two-to-three sigma lines')
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210621', 0.924, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department C', 'TOTAL'       , NULL, NULL, NULL, '20210628', 0.923, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C1'     , 'Department C', NULL, NULL, NULL, '20210104', 0.913, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C1'     , 'Department C', NULL, NULL, NULL, '20210111', 0.911, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C1'     , 'Department C', NULL, NULL, NULL, '20210118', 0.912, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C1'     , 'Department C', NULL, NULL, NULL, '20210125', 0.909, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C2'     , 'Department C', NULL, NULL, NULL, '20210201', 0.912, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C2'     , 'Department C', NULL, NULL, NULL, '20210208', 0.923, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C2'     , 'Department C', NULL, NULL, NULL, '20210215', 0.916, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C2'     , 'Department C', NULL, NULL, NULL, '20210222', 0.923, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C3'     , 'Department C', NULL, NULL, NULL, '20210301', 0.912, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C3'     , 'Department C', NULL, NULL, NULL, '20210308', 0.905, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C3'     , 'Department C', NULL, NULL, NULL, '20210315', 0.905, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C4'     , 'Department C', NULL, NULL, NULL, '20210322', 0.9  , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C4'     , 'Department C', NULL, NULL, NULL, '20210329', 0.902, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C4'     , 'Department C', NULL, NULL, NULL, '20210405', 0.913, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C5'     , 'Department C', NULL, NULL, NULL, '20210412', 0.91 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C5'     , 'Department C', NULL, NULL, NULL, '20210419', 0.905, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C5'     , 'Department C', NULL, NULL, NULL, '20210426', 0.912, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C6'     , 'Department C', NULL, NULL, NULL, '20210503', 0.91 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C6'     , 'Department C', NULL, NULL, NULL, '20210510', 0.907, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C6'     , 'Department C', NULL, NULL, NULL, '20210517', 0.915, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C7'     , 'Department C', NULL, NULL, NULL, '20210524', 0.912, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C7'     , 'Department C', NULL, NULL, NULL, '20210531', 0.909, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C7'     , 'Department C', NULL, NULL, NULL, '20210607', 0.92 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C8'     , 'Department C', NULL, NULL, NULL, '20210614', 0.923, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C8'     , 'Department C', NULL, NULL, NULL, '20210621', 0.924, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area C8'     , 'Department C', NULL, NULL, NULL, '20210628', 0.923, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210104', 0.971, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210111', 0.973, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210118', 0.978, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210125', 0.979, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210201', 0.981, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210208', 0.985, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210215', 0.987, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210222', 0.991, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210301', 0.993, 0, 0, 'Start of decrease (concern) while still above mean (improvement)')
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210308', 0.987, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210315', 0.982, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210322', 0.98 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210329', 0.979, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210405', 0.972, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210412', 0.964, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210419', 0.962, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210426', 0.958, 0, 0, 'Start of increase (improvement) while still below mean (concern)')
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210503', 0.96 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210510', 0.961, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210517', 0.963, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210524', 0.964, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210531', 0.965, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210607', 0.966, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210614', 0.968, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210621', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Department D', 'TOTAL'       , NULL, NULL, NULL, '20210628', 0.972, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D1'     , 'Department D', 1   , NULL, NULL, '20210104', 0.971, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D1'     , 'Department D', 1   , NULL, NULL, '20210111', 0.973, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D2'     , 'Department D', 2   , NULL, NULL, '20210118', 0.978, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D2'     , 'Department D', 2   , NULL, NULL, '20210125', 0.979, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D3'     , 'Department D', 3   , NULL, NULL, '20210201', 0.981, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D3'     , 'Department D', 3   , NULL, NULL, '20210208', 0.985, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D4'     , 'Department D', 4   , NULL, NULL, '20210215', 0.987, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D4'     , 'Department D', 4   , NULL, NULL, '20210222', 0.991, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D5'     , 'Department D', 5   , NULL, NULL, '20210301', 0.993, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D5'     , 'Department D', 5   , NULL, NULL, '20210308', 0.987, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D6'     , 'Department D', 6   , NULL, NULL, '20210315', 0.982, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D6'     , 'Department D', 6   , NULL, NULL, '20210322', 0.98 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D7'     , 'Department D', 7   , NULL, NULL, '20210329', 0.979, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D7'     , 'Department D', 7   , NULL, NULL, '20210405', 0.972, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D8'     , 'Department D', 8   , NULL, NULL, '20210412', 0.964, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D8'     , 'Department D', 8   , NULL, NULL, '20210419', 0.962, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D9'     , 'Department D', 9   , NULL, NULL, '20210426', 0.958, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D9'     , 'Department D', 9   , NULL, NULL, '20210503', 0.96 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D10'    , 'Department D', 10  , NULL, NULL, '20210510', 0.961, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D10'    , 'Department D', 10  , NULL, NULL, '20210517', 0.963, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D11'    , 'Department D', 11  , NULL, NULL, '20210524', 0.964, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D11'    , 'Department D', 11  , NULL, NULL, '20210531', 0.965, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D12'    , 'Department D', 12  , NULL, NULL, '20210607', 0.966, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D12'    , 'Department D', 12  , NULL, NULL, '20210614', 0.968, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D13'    , 'Department D', 13  , NULL, NULL, '20210621', 0.97 , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M1', 'Area D13'    , 'Department D', 13  , NULL, NULL, '20210628', 0.972, 0, 0, NULL)

INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20160101', 13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20160201', 16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20160301', 14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20160401', 13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20160501', 15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20160601', 16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20160701', 18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20160801', 16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20160901', 17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20161001', 15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20161101', 13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20161201', 16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20170101', 15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20170201', 14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20170301', 13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20170401', 16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20170501', 19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20170601', 17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20170701', 12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20170801', 14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20170901', 17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20171001', 19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20171101', 16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20171201', 17, 0, 0, 'Baseline set')
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20180101', 16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20180201', 13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20180301', 18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20180401', 22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20180501', 19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20180601', 19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20180701', 18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20180801', 19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20180901', 17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20181001', 21, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20181101', 20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20181201', 14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20190101', 18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20190201', 17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20190301', 15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20190401', 16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20190501', 19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20190601', 21, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20190701', 17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20190801', 14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20190901',  8, 1, 0, 'Limits recalculated')
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20191001',  6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20191101',  5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20191201',  3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20200101',  5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20200201',  4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20200301',  6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20200401',  5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20200501',  4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20200601',  6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20200701',  7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20200801',  5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20200901',  5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20201001', 27, 0, 1, 'Ghosted')
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20201101',  6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20201201',  2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20210101',  5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20210201',  7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20210301',  5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20210401',  4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20210501',  5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M2', 'TOTAL', NULL, NULL, NULL, NULL, '20210601',  6, 0, 0, NULL)

INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210101', 2150, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210102', 2351, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210103', 2456, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210104', 2185, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210105', 2422, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210106', 2121, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210107', 2220, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210108', 2015, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210109', 1818, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210110', 1898, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210111', 1952, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210112', 2051, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210113', 2261, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210114', 2115, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210115', 3105, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210116', 2654, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210117', 2421, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210118', 2940, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210119', 2552, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M3', 'TOTAL', NULL, NULL, NULL, NULL, '20210120', 2807, 0, 0, NULL)

INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210101', 0.604166666666667, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210102', 0.614583333333333, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210103', 0.6125           , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210104', 0.602777777777778, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210105', 0.621527777777778, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210106', 0.615972222222222, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210107', 0.624305555555556, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210108', 0.627083333333333, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210109', 0.625            , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210110', 0.629861111111111, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210111', 0.630555555555556, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210112', 0.63125          , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210113', 0.627083333333333, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210114', 0.623611111111111, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210115', 0.615972222222222, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210116', 0.627777777777778, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210117', 0.631944444444444, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210118', 0.6375           , 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210119', 0.633333333333333, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M4', 'TOTAL', NULL, NULL, NULL, NULL, '20210120', 0.627083333333333, 0, 0, NULL)

INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20190224', 43, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20190508', 73, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20190613', 36, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20190810', 58, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20190916', 37, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20191019', 33, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20191204', 46, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20200119', 46, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20200216', 28, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20200308', 21, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20200507', 60, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20200619', 43, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20200825', 67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20201028', 64, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20201130', 33, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20210217', 79, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20210401', 43, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20210411', 10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M5', 'TOTAL', NULL, NULL, NULL, NULL, '20210616', 66, 0, 0, NULL)

INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20190112', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20190224', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20190508', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20190613', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20190810', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20190916', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20191019', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20191204', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20200119', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20200216', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20200308', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20200507', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20200619', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20200825', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20201028', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20201130', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20210217', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20210401', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20210411', NULL, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M6', 'TOTAL', NULL, NULL, NULL, NULL, '20210616', NULL, 0, 0, NULL)

INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20190224',  5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20190508', 15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20190613',  9, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20190810', 12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20190916',  9, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20191019',  8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20191204', 16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20200119', 12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20200216',  7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20200308',  6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20200507', 27, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20200619', 22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20200825', 22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20201028', 32, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20201130', 17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20210217', 51, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20210401', 22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20210411', 14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M7', 'TOTAL', NULL, NULL, NULL, NULL, '20210616', 30, 0, 0, NULL)

INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200101',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20200101',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200101',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20200101',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20200101',  27, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20200101',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20200101',  56, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200201',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20200201',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200201',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20200201',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20200201',  28, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20200201',  34, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20200201',  62, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200301',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20200301',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200301',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20200301',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20200301',  25, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20200301',  34, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20200301',  59, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200401',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20200401',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200401',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20200401',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20200401',  32, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20200401',  31, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20200401',  63, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200501',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20200501',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200501',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20200501',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20200501',  28, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20200501',  34, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20200501',  62, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200601',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20200601',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200601',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20200601',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20200601',  27, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20200601',  40, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20200601',  67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200701',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20200701',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200701',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20200701',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20200701',  34, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20200701',  34, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20200701',  68, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200801',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20200801',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200801',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20200801',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20200801',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20200801',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20200801',  51, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200901',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20200901',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200901',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20200901',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20200901',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20200901',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20200901',  52, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20201001',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20201001',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20201001',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20201001',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20201001',  33, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20201001',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20201001',  50, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20201101',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20201101',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20201101',   4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20201101',   4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20201101',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20201101',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20201101',  49, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20201201',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20201201',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20201201',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20201201',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20201201',  28, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20201201',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20201201',  48, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20210101',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20210101',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20210101',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20210101',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20210101',  28, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20210101',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20210101',  46, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20210201',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20210201',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20210201',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20210201',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20210201',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20210201',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20210201',  43, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type A', '20210301',   9, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type A', '20210301',   9, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', 'Sub Type B', '20210301',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , 'Sub Type B', '20210301',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 1', NULL        , '20210301',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, 'Type 2', NULL        , '20210301',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1' , NULL        , NULL, NULL    , NULL        , '20210301',  41, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200101',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20200101',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200101',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20200101',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20200101',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20200101',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20200101',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200201',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20200201',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200201',   1, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20200201',   1, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20200201',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20200201',   4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20200201',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200301',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20200301',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200301',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20200301',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20200301',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20200301',   4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20200301',   9, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200401',   1, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20200401',   1, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200401',   0, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20200401',   0, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20200401',   9, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20200401',   1, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20200401',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200501',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20200501',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200501',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20200501',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20200501',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20200501',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20200501',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200601',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20200601',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200601',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20200601',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20200601',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20200601',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20200601',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200701',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20200701',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200701',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20200701',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20200701',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20200701',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20200701',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200801',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20200801',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200801',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20200801',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20200801',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20200801',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20200801',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200901',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20200901',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200901',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20200901',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20200901',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20200901',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20200901',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20201001',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20201001',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20201001',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20201001',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20201001',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20201001',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20201001',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20201101',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20201101',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20201101',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20201101',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20201101',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20201101',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20201101',  21, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20201201',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20201201',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20201201',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20201201',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20201201',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20201201',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20201201',  23, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20210101',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20210101',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20210101',   4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20210101',   4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20210101',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20210101',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20210101',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20210201',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20210201',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20210201',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20210201',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20210201',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20210201',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20210201',  21, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20210301',   4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type A', '20210301',   4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20210301',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , 'Sub Type B', '20210301',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 1', NULL        , '20210301',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, 'Type 2', NULL        , '20210301',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1a', 'Category 1', NULL, NULL    , NULL        , '20210301',  21, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200101',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20200101',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200101',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20200101',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20200101',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20200101',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20200101',  43, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200201',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20200201',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200201',  16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20200201',  16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20200201',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20200201',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20200201',  52, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200301',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20200301',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200301',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20200301',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20200301',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20200301',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20200301',  50, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200401',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20200401',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200401',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20200401',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20200401',  23, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20200401',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20200401',  53, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200501',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20200501',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200501',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20200501',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20200501',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20200501',  28, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20200501',  50, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200601',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20200601',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200601',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20200601',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20200601',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20200601',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20200601',  52, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200701',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20200701',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200701',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20200701',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20200701',  27, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20200701',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20200701',  46, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200801',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20200801',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200801',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20200801',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20200801',  21, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20200801',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20200801',  32, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20200901',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20200901',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20200901',   4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20200901',   4, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20200901',  23, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20200901',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20200901',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20201001',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20201001',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20201001',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20201001',   3, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20201001',  23, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20201001',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20201001',  33, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20201101',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20201101',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20201101',   1, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20201101',   1, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20201101',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20201101',   9, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20201101',  28, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20201201',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20201201',   6, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20201201',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20201201',   2, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20201201',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20201201',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20201201',  25, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20210101',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20210101',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20210101',   1, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20210101',   1, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20210101',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20210101',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20210101',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20210201',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20210201',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20210201',   0, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20210201',   0, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20210201',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20210201',   7, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20210201',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type A', '20210301',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type A', '20210301',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', 'Sub Type B', '20210301',   0, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , 'Sub Type B', '20210301',   0, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 1', NULL        , '20210301',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, 'Type 2', NULL        , '20210301',   5, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 1b', 'Category 1', NULL, NULL    , NULL        , '20210301',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200101',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20200101',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200101',  39, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20200101',  39, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20200101',  70, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20200101',  63, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20200101', 133, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200201',  34, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20200201',  34, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200201',  40, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20200201',  40, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20200201',  60, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20200201',  74, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20200201', 134, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200301',  37, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20200301',  37, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200301',  44, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20200301',  44, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20200301',  65, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20200301',  81, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20200301', 146, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200401',  32, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20200401',  32, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200401',  41, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20200401',  41, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20200401',  61, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20200401',  73, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20200401', 134, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200501',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20200501',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200501',  36, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20200501',  36, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20200501',  57, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20200501',  71, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20200501', 128, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200601',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20200601',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200601',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20200601',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20200601',  67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20200601',  46, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20200601', 113, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200701',  26, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20200701',  26, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200701',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20200701',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20200701',  57, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20200701',  56, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20200701', 113, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200801',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20200801',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200801',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20200801',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20200801',  65, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20200801',  64, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20200801', 129, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20200901',  32, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20200901',  32, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20200901',  42, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20200901',  42, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20200901',  65, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20200901',  74, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20200901', 139, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20201001',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20201001',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20201001',  43, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20201001',  43, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20201001',  63, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20201001',  67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20201001', 130, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20201101',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20201101',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20201101',  50, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20201101',  50, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20201101',  73, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20201101',  72, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20201101', 145, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20201201',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20201201',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20201201',  41, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20201201',  41, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20201201',  70, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20201201',  65, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20201201', 135, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20210101',  25, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20210101',  25, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20210101',  42, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20210101',  42, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20210101',  67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20210101',  67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20210101', 134, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20210201',  26, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20210201',  26, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20210201',  47, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20210201',  47, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20210201',  64, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20210201',  73, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20210201', 137, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type A', '20210301',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type A', '20210301',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', 'Sub Type B', '20210301',  48, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , 'Sub Type B', '20210301',  48, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 1', NULL        , '20210301',  73, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, 'Type 2', NULL        , '20210301',  77, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2' , NULL        , NULL, NULL    , NULL        , '20210301', 150, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200101',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20200101',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200101',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20200101',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20200101',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20200101',  31, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20200101',  66, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200201',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20200201',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200201',  25, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20200201',  25, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20200201',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20200201',  44, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20200201',  74, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200301',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20200301',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200301',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20200301',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20200301',  32, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20200301',  41, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20200301',  73, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200401',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20200401',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200401',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20200401',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20200401',  28, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20200401',  39, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20200401',  67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200501',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20200501',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200501',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20200501',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20200501',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20200501',  38, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20200501',  67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200601',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20200601',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200601',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20200601',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20200601',  38, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20200601',  26, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20200601',  64, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200701',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20200701',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200701',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20200701',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20200701',  26, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20200701',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20200701',  56, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200801',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20200801',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200801',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20200801',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20200801',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20200801',  26, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20200801',  55, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200901',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20200901',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200901',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20200901',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20200901',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20200901',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20200901',  65, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20201001',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20201001',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20201001',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20201001',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20201001',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20201001',  28, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20201001',  58, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20201101',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20201101',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20201101',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20201101',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20201101',  31, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20201101',  32, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20201101',  63, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20201201',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20201201',  13, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20201201',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20201201',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20201201',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20201201',  31, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20201201',  61, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20210101',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20210101',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20210101',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20210101',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20210101',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20210101',  34, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20210101',  63, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20210201',  16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20210201',  16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20210201',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20210201',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20210201',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20210201',  38, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20210201',  67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20210301',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type A', '20210301',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20210301',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , 'Sub Type B', '20210301',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 1', NULL        , '20210301',  27, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, 'Type 2', NULL        , '20210301',  42, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2a', 'Category 2', NULL, NULL    , NULL        , '20210301',  69, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200101',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20200101',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200101',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20200101',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20200101',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20200101',  32, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20200101',  67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200201',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20200201',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200201',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20200201',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20200201',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20200201',  30, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20200201',  60, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200301',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20200301',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200301',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20200301',  22, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20200301',  33, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20200301',  40, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20200301',  73, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200401',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20200401',  15, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200401',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20200401',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20200401',  33, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20200401',  34, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20200401',  67, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200501',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20200501',  17, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200501',  16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20200501',  16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20200501',  28, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20200501',  33, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20200501',  61, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200601',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20200601',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200601',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20200601',   8, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20200601',  29, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20200601',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20200601',  49, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200701',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20200701',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200701',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20200701',  12, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20200701',  31, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20200701',  26, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20200701',  57, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200801',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20200801',  18, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200801',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20200801',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20200801',  36, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20200801',  38, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20200801',  74, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20200901',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20200901',  19, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20200901',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20200901',  20, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20200901',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20200901',  39, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20200901',  74, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20201001',  16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20201001',  16, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20201001',  23, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20201001',  23, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20201001',  33, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20201001',  39, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20201001',  72, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20201101',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20201101',  14, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20201101',  26, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20201101',  26, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20201101',  42, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20201101',  40, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20201101',  82, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20201201',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20201201',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20201201',  23, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20201201',  23, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20201201',  40, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20201201',  34, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20201201',  74, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20210101',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20210101',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20210101',  23, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20210101',  23, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20210101',  38, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20210101',  33, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20210101',  71, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20210201',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20210201',  10, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20210201',  25, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20210201',  25, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20210201',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20210201',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20210201',  70, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type A', '20210301',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type A', '20210301',  11, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', 'Sub Type B', '20210301',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , 'Sub Type B', '20210301',  24, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 1', NULL        , '20210301',  46, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, 'Type 2', NULL        , '20210301',  35, 0, 0, NULL)
INSERT INTO #RawData VALUES ('M8', 'Category 2b', 'Category 2', NULL, NULL    , NULL        , '20210301',  81, 0, 0, NULL)

    -- Example of populating from a table:

        -- INSERT INTO #RawData
        -- SELECT <the eight columns needed, in the correct order, with suitable data types>
        -- FROM <source table>
        -- WHERE <optional conditions>

    -- Example of populating from a stored procedure that only returns the eight columns needed, in the correct order, with suitable data types:

        -- INSERT INTO RawData
        -- EXEC <stored procedure>

    -- Example of populating from a stored procedure that returns additional columns, or the eight columns needed in a different order:

        -- IF OBJECT_ID('tempdb..#RawDataStoredProcedureStaging') IS NOT NULL DROP TABLE #RawDataStoredProcedureStaging
        -- CREATE TABLE #RawDataStoredProcedureStaging (
        --                                               <all the columns returned from the stored procedure, with their data types>
        --                                             )

        -- INSERT INTO #RawDataStoredProcedureStaging
        -- EXEC <stored procedure>

        -- INSERT INTO #RawData
        -- SELECT <the eight columns needed, in the correct order, with suitable data types>
        -- FROM RawDataStoredProcedureStaging
        -- WHERE <optional conditions>

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3b complete, raw data'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3C: BASELINE DATA
--====================================================================================================================================================================================================--
--
-- This step is where the baseline data is entered
-- If there are no baselines, do not insert any data into #BaselineData but do not remove the table creation
--
-- The data must match the columns created in #BaselineData
-- The data types can be changed, as detailed below, to reduce size
--
-- [BaselineOrder] is used to control which baseline to keep if multiple are provided; this is added automatically but could be manually controlled; if multiple baselines are provided for any metric/group combination, the first is used
-- [MetricID] must match a row in #MetricData and #RawData
-- [Group] must match a row in #RawData; if set as NULL, it will be applied to all groups
-- [Date] and/or [PointsExcludeGhosting] must be provided; if both are provided and conflict, [Date] is used
--     • This is the last point in the baseline, similar to recalculating the next point
--
-- The data can be inserted into #BaselineData one line at a time, as shown in the sample data below, or populated from a table or stored procedure (see examples in Step 3b)
-- The accompanying Excel file also contains a worksheet to generate INSERT lines
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [BaselineOrder] is duplicated
--     • [MetricID] does not exist in #MetricData (Step 3a) or #RawData (Step 3b)
--     • [Group] does not exist in #RawData (Step 3b) for that metric
--     • [Date] does not exist in #RawData (Step 3b) for that metric for either that group (if specified) or at least one group (if not specified)
--     • Multiple baselines are provided for metric/group combination
--     • Baseline includes special cause variation
--
--====================================================================================================================================================================================================--

-- Create temporary table
CREATE TABLE #BaselineData (
                             [BaselineOrder]         INT           IDENTITY(1, 1) NOT NULL -- IDENTITY(1, 1) can be removed
                            ,[MetricID]              NVARCHAR(MAX)                NOT NULL -- Can be reduced in size
                            ,[Group]                 NVARCHAR(MAX)                    NULL -- Can be reduced in size
                            ,[Date]                  DATE                             NULL
                            ,[PointsExcludeGhosting] INT                              NULL
                           )

-- Insert sample data for various baselines
INSERT INTO #BaselineData VALUES ('M2', 'TOTAL', '20171201', NULL)

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3c complete, baseline data'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3D: TARGET DATA
--====================================================================================================================================================================================================--
--
-- This step is where the target data is entered for XmR charts
-- If there are no targets, do not insert any data into #TargetData but do not remove the table creation
--
-- The data must match the columns created in #TargetData
-- The data types can be changed, as detailed below, to reduce size
--
-- [TargetOrder] is used to control which target to keep if multiple are provided; this is added automatically but could be manually controlled; if multiple targets are provided for any metric/group/date combination, the first is used
-- [MetricID] must match a row in #MetricData and #RawData
-- [Group] must match a row in #RawData; if set as NULL, it will be applied to all groups
-- [Target] must be provided
-- [StartDate] and/or [EndDate] can be left as NULL
--
-- The data can be inserted into #TargetData one line at a time, as shown in the sample data below, or populated from a table or stored procedure (see examples in Step 3b)
-- The accompanying Excel file also contains a worksheet to generate INSERT lines
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [TargetOrder] is duplicated
--     • [MetricID] does not exist in #MetricData (Step 3a) or #RawData (Step 3b)
--     • [Group] does not exist in #RawData (Step 3b) for that metric
--     • [StartDate] is after [EndDate]
--     • Multiple targets are provided for metric/group/date combination
--     • Target provided for metric when [MetricImprovement] is not 'Up' or 'Down'
--     • Target provided for metric when [ChartType] is 'T' or 'G'
--
--====================================================================================================================================================================================================--

-- Create temporary table
CREATE TABLE #TargetData (
                           [TargetOrder] INT             IDENTITY(1, 1) NOT NULL -- IDENTITY(1, 1) can be removed
                          ,[MetricID]    NVARCHAR(MAX)                  NOT NULL -- Can be reduced in size
                          ,[Group]       NVARCHAR(MAX)                      NULL -- Can be reduced in size
                          ,[Target]      DECIMAL(38, 19)                NOT NULL -- Can be reduced in size (might affect accuracy of calculations)
                          ,[StartDate]   DATE                               NULL
                          ,[EndDate]     DATE                               NULL
                         )

-- Insert sample data for various targets
INSERT INTO #TargetData VALUES ('M1', NULL   , 0.95, NULL, NULL)
INSERT INTO #TargetData VALUES ('M2', 'TOTAL', 12  , NULL, NULL)

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3d complete, target data'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4A: HIERARCHY
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates the group order based on the hierarchy
--
--====================================================================================================================================================================================================--

-- Create distinct list for group hierarchy recursion below
SELECT DISTINCT
       [Group]
      ,[GroupParent]
      ,[GroupHierarchyOrder]
INTO #SPCCalculationsDistinctGroups
FROM #RawData

-- Create hierarchy, across all metrics, based on [GroupParent] and then [Group] in alphabetical order
-- Must either be NULL or set to a [Group] that also exists, and cannot be in a loop
;WITH DistinctGroups AS (
                          SELECT *
                          FROM #SPCCalculationsDistinctGroups
                        ),
      GroupHierarchy AS (
                          SELECT    [GroupLevel]     = CAST(1.0 * ROW_NUMBER() OVER(PARTITION BY t1.[GroupParent] ORDER BY t1.[GroupHierarchyOrder], t1.[Group]) / COUNT(ISNULL(t1.[GroupParent], 1)) OVER() AS VARCHAR(MAX))
                                ,   [GroupHierarchy] = 1
                                ,t1.[Group]
                                ,t1.[GroupParent]
                          FROM #SPCCalculationsDistinctGroups AS t1
                          WHERE [GroupParent] IS NULL
                 
                          UNION ALL
                 
                          SELECT    [GroupLevel]     = [GroupLevel] + CAST(1.0 * ROW_NUMBER() OVER(PARTITION BY t2.[GroupParent] ORDER BY t2.[GroupHierarchyOrder], t2.[Group]) / COUNT(ISNULL(t2.[GroupParent], 1)) OVER() AS VARCHAR(MAX))
                                ,   [GroupHierarchy] = 1 + [GroupHierarchy]
                                ,t2.[Group]
                                ,t2.[GroupParent]
                          FROM #SPCCalculationsDistinctGroups AS t2
                          INNER JOIN GroupHierarchy AS g ON g.[Group] = t2.[GroupParent]
                        )
SELECT [GroupOrder]  = ROW_NUMBER() OVER(ORDER BY [GroupLevel])
      ,[GroupHierarchy]
      ,[Group]
INTO #SPCCalculationsHierarchy
FROM GroupHierarchy
OPTION (MAXRECURSION 0)

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4a complete, hierarchy'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4B: PARTITIONS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step combines data and adds partitions
--
--====================================================================================================================================================================================================--

-- Join metric and raw data along with the hierarchy
-- Add row ID (used for self-joins below) and chart ID
-- Add point rank (used for baselines and icons and to exclude first T chart point)
-- Replace NULL in [ChartTitle], [VerticalAxisTitle], [HorizontalAxisTitle], and [Annotation] with empty text
-- Add dropdown version of group with indentation
-- Add partitions for each metric/group/filter combination based on when limits are recalculated, including partition without ghosted points (used for mean and moving range calculations)
SELECT   [RowID]                              = CASE WHEN m.[ChartType] = 'T'          THEN CONCAT(r.[MetricID], '||', h.[GroupHierarchy], '||', r.[Group], '||', ISNULL(r.[Filter1], '< No Filter >'), '||', ISNULL(r.[Filter2], '< No Filter >'), '||', ROW_NUMBER() OVER(PARTITION BY m.[MetricOrder], h.[GroupOrder], r.[Filter1], r.[Filter2]                ORDER BY r.[Date]) - 1)
                                                                                       ELSE CONCAT(r.[MetricID], '||', h.[GroupHierarchy], '||', r.[Group], '||', ISNULL(r.[Filter1], '< No Filter >'), '||', ISNULL(r.[Filter2], '< No Filter >'), '||', ROW_NUMBER() OVER(PARTITION BY m.[MetricOrder], h.[GroupOrder], r.[Filter1], r.[Filter2]                ORDER BY r.[Date])) END
      ,  [ChartID]                            =                                             CONCAT(r.[MetricID], '||', h.[GroupHierarchy], '||', r.[Group], '||', ISNULL(r.[Filter1], '< No Filter >'), '||', ISNULL(r.[Filter2], '< No Filter >'))
      ,  [PointRank]                          = CASE WHEN m.[ChartType] = 'T'          THEN                                                                                                                                                               ROW_NUMBER() OVER(PARTITION BY m.[MetricOrder], h.[GroupOrder], r.[Filter1], r.[Filter2]                ORDER BY r.[Date]) - 1
                                                                                       ELSE                                                                                                                                                               ROW_NUMBER() OVER(PARTITION BY m.[MetricOrder], h.[GroupOrder], r.[Filter1], r.[Filter2]                ORDER BY r.[Date]) END
      ,  [PointExcludeGhostingRankAscending]  = CASE WHEN r.[GhostFlag] = 1            THEN NULL                                                                                                                                                          
                                                                                       ELSE                                                                                                                                                               ROW_NUMBER() OVER(PARTITION BY m.[MetricOrder], h.[GroupOrder], r.[Filter1], r.[Filter2], r.[GhostFlag] ORDER BY r.[Date]) END
      ,  [PointExcludeGhostingRankDescending] = CASE WHEN r.[GhostFlag] = 1            THEN NULL                                                                                                                                                          
                                                                                       ELSE                                                                                                                                                               ROW_NUMBER() OVER(PARTITION BY m.[MetricOrder], h.[GroupOrder], r.[Filter1], r.[Filter2], r.[GhostFlag] ORDER BY r.[Date] DESC) END
      ,m.[MetricOrder]                            
      ,m.[MetricID]                                
      ,m.[MetricName]                             
      ,m.[ChartType]
      ,m.[MetricImprovement]
      ,m.[MetricConflictRule]
      ,m.[DateFormat]
      ,m.[MetricFormat]
      ,m.[LowMeanWarningValue]
      ,  [ChartTitle]                         = ISNULL(m.[ChartTitle]         , '')
      ,  [HorizontalAxisTitle]                = ISNULL(m.[HorizontalAxisTitle], '')
      ,  [VerticalAxisTitle]                  = ISNULL(m.[VerticalAxisTitle]  , '')
      ,m.[VerticalAxisMinFix]
      ,m.[VerticalAxisMinFlex]
      ,m.[VerticalAxisMaxFix]
      ,m.[VerticalAxisMaxFlex]
      ,h.[GroupOrder]
      ,h.[GroupHierarchy]
      ,r.[Group]
      ,  [GroupName]                          = CONCAT(REPLICATE(' ', (h.[GroupHierarchy] - 1) * @SettingGroupHierarchyIndentSpaces), LTRIM(RTRIM(r.[Group])))
      ,  [Filter1]                            = ISNULL(r.[Filter1], '< No Filter >')
      ,  [Filter2]                            = ISNULL(r.[Filter2], '< No Filter >')
      ,r.[Date]
      ,r.[Value]                                 
      ,r.[RecalculateLimitsFlag]                 
      ,r.[GhostFlag]                             
      ,  [Annotation]                         = ISNULL(r.[Annotation], '')
      ,  [PartitionID]                        =                                  SUM(r.[RecalculateLimitsFlag]) OVER(PARTITION BY r.[MetricID], r.[Group], r.[Filter1], r.[Filter2] ORDER BY r.[Date]) + 1
      ,  [PartitionIDExcludeGhosting]         = CASE WHEN r.[GhostFlag] = 1 THEN NULL
                                                                            ELSE SUM(r.[RecalculateLimitsFlag]) OVER(PARTITION BY r.[MetricID], r.[Group], r.[Filter1], r.[Filter2] ORDER BY r.[Date]) + 1 END
INTO #SPCCalculationsPartition
FROM #MetricData                         AS m
    INNER JOIN #RawData                  AS r ON r.[MetricID] = m.[MetricID]
    INNER JOIN #SPCCalculationsHierarchy AS h ON h.[Group]    = r.[Group]

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4b complete, partitions'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4C: BASELINES
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds baselines and then updates partitions
--
--====================================================================================================================================================================================================--

-- Add baseline end flags
-- If multiple baselines are provided for metric/group combination, add rank for updating below
-- If both [Date] and [PointsExcludeGhosting] are provided and these conflict, use [Date]
SELECT p.*
      ,  [BaselineEndFlag] = CASE WHEN b.[MetricID] IS NOT NULL THEN 1
                                                                ELSE 0 END
      ,  [BaselineEndRank] = CASE WHEN b.[MetricID] IS NOT NULL THEN ROW_NUMBER() OVER(PARTITION BY p.[ChartID], b.[MetricID] ORDER BY b.[BaselineOrder], CASE WHEN b.[Date] = p.[Date] THEN 0
                                                                                                                                                                                        ELSE 1 END) END
INTO #SPCCalculationsBaselineFlag
FROM #SPCCalculationsPartition AS p
LEFT JOIN #BaselineData        AS b ON b.[MetricID]                 = p.[MetricID]
                                   AND ISNULL(b.[Group], p.[Group]) = p.[Group]
                                   AND (b.[Date]                    = p.[Date]
                                     OR b.[PointsExcludeGhosting]   = p.[PointExcludeGhostingRankAscending])

-- When extra baselines are provided for metric/group combination, remove based on rank
UPDATE #SPCCalculationsBaselineFlag
SET [BaselineEndFlag] = 0
WHERE [BaselineEndFlag] = 1
  AND [BaselineEndRank] > 1

-- Add baseline flag for all points up to and including baseline end flag for metric/group combination
SELECT bf1.*
      ,    [BaselineFlag] = CASE WHEN bf1.[Date] <= bf2.[Date] THEN 1
                                                               ELSE 0 END
INTO #SPCCalculationsBaseline
FROM #SPCCalculationsBaselineFlag AS bf1
LEFT JOIN (
            SELECT [ChartID]
                  ,[Group]
                  ,[Date]
            FROM #SPCCalculationsBaselineFlag
            WHERE [BaselineEndFlag] = 1
          ) AS bf2 ON bf2.[ChartID] = bf1.[ChartID]

-- Update partition IDs for baseline points
UPDATE #SPCCalculationsBaseline
SET [PartitionID]                = 0
   ,[PartitionIDExcludeGhosting] = CASE WHEN [GhostFlag] = 1 THEN NULL
                                                             ELSE 0 END
WHERE [BaselineFlag] = 1

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4c complete, baselines'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4D: TARGETS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds targets for XmR charts
--
--====================================================================================================================================================================================================--

-- Add targets
-- If multiple targets are provided for metric/group/date combination, add rank for updating below
-- If metric improvement is 'neither', ignore
SELECT b.*
      ,t.[Target]
      ,  [TargetRank] = ROW_NUMBER() OVER(PARTITION BY b.[ChartID], b.[Date] ORDER BY t.[TargetOrder])
INTO #SPCCalculationsAllTargets
FROM #SPCCalculationsBaseline AS b
LEFT JOIN #TargetData         AS t ON t.[MetricID]                     = b.[MetricID]
                                  AND ISNULL(t.[Group]    , b.[Group]) = b.[Group]
                                  AND ISNULL(t.[StartDate], b.[Date]) <= b.[Date]
                                  AND ISNULL(t.[EndDate]  , b.[Date]) >= b.[Date]
                                  AND b.[MetricImprovement] IN ('Up', 'Down')
                                  AND b.[ChartType] NOT IN ('T', 'G')

-- When extra targets are provided for metric/group/date combination, remove all but the first
SELECT *
INTO #SPCCalculationsSingleTarget
FROM #SPCCalculationsAllTargets
WHERE [TargetRank] = 1

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4d complete, targets'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4E: PROCESS LIMITS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates the mean, moving range, and process limits
--
--====================================================================================================================================================================================================--

-- Add number of days between events for T charts
SELECT *
      ,[DayDifference] = DATEDIFF(DAY, LAG([Date], 1) OVER(PARTITION BY [ChartID] ORDER BY [Date]), [Date])
INTO #SPCCalculationsDayDifference
FROM #SPCCalculationsSingleTarget
WHERE [ChartType] = 'T'

UNION ALL

SELECT *
      ,[DayDifference] = NULL
FROM #SPCCalculationsSingleTarget
WHERE [ChartType] <> 'T'

-- Transform day differences for mean calculation for T charts
SELECT *
      ,[DayDifferenceTransformed] = POWER(CAST([DayDifference] AS FLOAT), 1 / 3.6)
INTO #SPCCalculationsDayDifferenceTransformed
FROM #SPCCalculationsDayDifference

-- Add transformed day mean for each metric/group/filter/partition combination, excluding ghosted points, for T charts
SELECT *
      ,[DayDifferenceTransformedMean] = AVG([DayDifferenceTransformed]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting])
INTO #SPCCalculationsDayDifferenceTransformedMean
FROM #SPCCalculationsDayDifferenceTransformed

-- Add mean for each metric/group/filter/partition combination, excluding ghosted points
SELECT *
      ,[Mean] = CASE WHEN [GhostFlag] = 1   THEN NULL
                     WHEN [ChartType] = 'T' THEN POWER([DayDifferenceTransformedMean], 3.6)
                                            ELSE AVG([Value]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting]) END
INTO #SPCCalculationsMean
FROM #SPCCalculationsDayDifferenceTransformedMean

-- Add moving range for XmR charts, based on absolute difference from previous point, for each metric/group/partition/filter combination, excluding ghosted points and first non-ghosted point in partition
-- Add moving range without partition for use in mR chart
-- Add transformed day difference moving range for T charts
SELECT *
      ,[MovingRangeWithPartition]            = CASE WHEN [GhostFlag] = 1     THEN NULL
                                                    WHEN [ChartType] = 'XmR' THEN ABS([Value]                    - LAG([Value], 1)                    OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date])) END
      ,[MovingRange]                         = CASE WHEN [GhostFlag] = 1     THEN NULL                                                                
                                                    WHEN [ChartType] = 'XmR' THEN ABS([Value]                    - LAG([Value], 1)                    OVER(PARTITION BY [ChartID], [GhostFlag]                  ORDER BY [Date])) END
      ,[DayDifferenceTransformedMovingRange] = CASE WHEN [GhostFlag] = 1     THEN NULL
                                                                             ELSE ABS([DayDifferenceTransformed] - LAG([DayDifferenceTransformed], 1) OVER(PARTITION BY [ChartID], [GhostFlag]                  ORDER BY [Date])) END
INTO #SPCCalculationsMovingRange
FROM #SPCCalculationsMean

-- Add moving range mean for each metric/group/filter/partition combination, excluding those with no moving range (i.e ghosted points and first non-ghosted point in partition)
-- Create duplicate, for updating below, to be used specifically for process limit calculations
SELECT  mr.*
      ,mrm.[MovingRangeMean]
      ,    [MovingRangeMeanForProcessLimits] = mrm.[MovingRangeMean]
INTO #SPCCalculationsMovingRangeMean
FROM #SPCCalculationsMovingRange AS mr
LEFT JOIN (
            SELECT *
                  ,[MovingRangeMean] = AVG([MovingRangeWithPartition]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting])
            FROM #SPCCalculationsMovingRange
            WHERE [MovingRangeWithPartition] IS NOT NULL
           ) mrm ON mrm.[RowID] = mr.[RowID]

-- Add transformed day difference moving range mean for each metric/group/filter/partition combination, excluding those with no moving range (i.e ghosted points and first two non-ghosted points in partition), for T charts
SELECT  mr.*
      ,mrm.[DayDifferenceTransformedMovingRangeMean]
INTO #SPCCalculationsDayDifferenceTransformedMovingRangeMean
FROM #SPCCalculationsMovingRangeMean AS mr
LEFT JOIN (
            SELECT *
                  ,[DayDifferenceTransformedMovingRangeMean] = AVG([DayDifferenceTransformedMovingRange]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting])
            FROM #SPCCalculationsMovingRange
            WHERE [DayDifferenceTransformedMovingRange] IS NOT NULL
           ) mrm ON mrm.[RowID] = mr.[RowID]

-- Checks for setting (set in Step 2a)
IF @ExcludeMovingRangeOutliers = 1

    BEGIN
 
         -- Update moving range mean by recalculating with moving range outliers removed
        UPDATE mrm
        SET [MovingRangeMeanForProcessLimits] = [MovingRangeMeanWithoutOutliers]
        FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean AS mrm
        LEFT JOIN (
                    SELECT DISTINCT
                           [MovingRangeMeanWithoutOutliers] = AVG([MovingRangeWithPartition]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting])
                          ,[ChartID]
                          ,[PartitionID]
                    FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean
                    WHERE [MovingRangeWithPartition] <= [MovingRangeMean] * 3.267
                  ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                           AND mrm2.[PartitionID] = mrm.[PartitionID]

        -- Update mean by recalculating with moving range outliers removed
        UPDATE mrm
        SET [Mean] = [MeanWithoutOutliers]
        FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean AS mrm
        LEFT JOIN (
                    SELECT DISTINCT
                           [MeanWithoutOutliers] = CASE WHEN [GhostFlag] = 1 THEN NULL
                                                                             ELSE AVG([Value]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting]) END
                          ,[ChartID]
                          ,[PartitionID]
                    FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean
                    WHERE [MovingRangeWithPartition] <= [MovingRangeMean] * 3.267
                       OR [MovingRangeWithPartition] IS NULL
                  ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                           AND mrm2.[PartitionID] = mrm.[PartitionID]

    END

-- Update mean for those skipped above (i.e. ghosted points) by copying from mean within metric/group/filter/partition combination
UPDATE mrm
SET mrm.[Mean] = mrm2.[PartitionMean]
FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean AS mrm
LEFT JOIN (
            SELECT DISTINCT
                   [ChartID]
                  ,[PartitionID]
                  ,[PartitionMean] = AVG([Mean]) OVER(PARTITION BY [ChartID], [PartitionID])
            FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean
            WHERE [Mean] IS NOT NULL
          ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                   AND mrm2.[PartitionID] = mrm.[PartitionID]

-- Update moving range mean for those skipped above (i.e. ghosted points and first non-ghosted point in partition) by copying from moving range mean within metric/group/filter/partition combination
UPDATE mrm
SET mrm.[MovingRangeMean]                 = mrm2.[PartitionMovingRangeMean]
   ,mrm.[MovingRangeMeanForProcessLimits] = mrm2.[PartitionMovingRangeMeanForProcessLimits]
FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean AS mrm
LEFT JOIN (
            SELECT DISTINCT
                   [ChartID]
                  ,[PartitionID]
                  ,[PartitionMovingRangeMean]                 = AVG([MovingRangeMean])                 OVER(PARTITION BY [ChartID], [PartitionID])
                  ,[PartitionMovingRangeMeanForProcessLimits] = AVG([MovingRangeMeanForProcessLimits]) OVER(PARTITION BY [ChartID], [PartitionID])
            FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean
            WHERE [MovingRangeMean] IS NOT NULL
          ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                   AND mrm2.[PartitionID] = mrm.[PartitionID]

-- Update transformed day difference mean and moving range mean for those skipped above (i.e. ghosted points and first two non-ghosted point in partition) by copying from transformed day difference mean moving range mean within metric/group/filter/partition combination
UPDATE mrm
SET mrm.[DayDifferenceTransformedMean]            = mrm2.[PartitionDayDifferenceTransformedMean]
   ,mrm.[DayDifferenceTransformedMovingRangeMean] = mrm2.[PartitionDayDifferenceTransformedMovingRangeMean]
FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean AS mrm
LEFT JOIN (
            SELECT DISTINCT
                   [ChartID]
                  ,[PartitionID]
                  ,[PartitionDayDifferenceTransformedMean]            = AVG([DayDifferenceTransformedMean])            OVER(PARTITION BY [ChartID], [PartitionID])
                  ,[PartitionDayDifferenceTransformedMovingRangeMean] = AVG([DayDifferenceTransformedMovingRangeMean]) OVER(PARTITION BY [ChartID], [PartitionID])
            FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean
            WHERE [DayDifferenceTransformedMovingRangeMean] IS NOT NULL
          ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                   AND mrm2.[PartitionID] = mrm.[PartitionID]

-- Update mean, moving range mean, trasnformed day difference mean, and transformed day difference moving range mean for first partition after baseline within metric/group/filter/partition combination when a baseline is set
UPDATE mrm
SET mrm.[Mean]                                    = mrm2.[Mean]
   ,mrm.[MovingRangeMean]                         = mrm2.[MovingRangeMean]
   ,mrm.[MovingRangeMeanForProcessLimits]         = mrm2.[MovingRangeMeanForProcessLimits]
   ,mrm.[DayDifferenceTransformedMean]            = mrm2.[DayDifferenceTransformedMean]
   ,mrm.[DayDifferenceTransformedMovingRangeMean] = mrm2.[DayDifferenceTransformedMovingRangeMean]
FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean AS mrm
INNER JOIN (
             SELECT DISTINCT
                    [ChartID]
                   ,[PartitionID]
                   ,[Mean]
                   ,[MovingRangeMean]
                   ,[MovingRangeMeanForProcessLimits]
                   ,[DayDifferenceTransformedMean]
                   ,[DayDifferenceTransformedMovingRangeMean]
             FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean
             WHERE [PartitionID] = 0
           ) AS mrm2 ON mrm2.[ChartID] = mrm.[ChartID]
WHERE mrm.[PartitionID] = 1

-- Add moving range process limit and high point value
SELECT *
      ,[MovingRangeProcessLimit]   =                           [MovingRangeMean] * 3.267
      ,[MovingRangeHighPointValue] = CASE WHEN [MovingRange] > [MovingRangeMean] * 3.267 THEN [MovingRange] END
INTO #SPCCalculationsMovingRangeProcessLimit
FROM #SPCCalculationsDayDifferenceTransformedMovingRangeMean

-- Add upper and lower process limits along with one and two sigma lines
SELECT *
      ,[UpperProcessLimit] = CASE [ChartType] WHEN 'XmR' THEN       [Mean]                         + [MovingRangeMeanForProcessLimits]         * 2.66
                                              WHEN 'T'   THEN POWER([DayDifferenceTransformedMean] + [DayDifferenceTransformedMovingRangeMean] * 2.66             , 3.6)
                                              WHEN 'G'   THEN       [Mean]                         + SQRT([Mean] * ([Mean] + 1))                      *  3               END
      ,[UpperTwoSigma]     = CASE [ChartType] WHEN 'XmR' THEN       [Mean]                         + [MovingRangeMeanForProcessLimits]         * 2.66 * (2 / 3.0)
                                              WHEN 'T'   THEN POWER([DayDifferenceTransformedMean] + [DayDifferenceTransformedMovingRangeMean] * 2.66 * (2 / 3.0) , 3.6) END
      ,[UpperOneSigma]     = CASE [ChartType] WHEN 'XmR' THEN       [Mean]                         + [MovingRangeMeanForProcessLimits]         * 2.66 * (1 / 3.0)
                                              WHEN 'T'   THEN POWER([DayDifferenceTransformedMean] + [DayDifferenceTransformedMovingRangeMean] * 2.66 * (1 / 3.0) , 3.6) END

      ,[LowerOneSigma]     = CASE [ChartType] WHEN 'XmR' THEN       [Mean]                         - [MovingRangeMeanForProcessLimits]         * 2.66 * (1 / 3.0)
                                              WHEN 'T'   THEN
                                                    CASE WHEN       [DayDifferenceTransformedMean] - [DayDifferenceTransformedMovingRangeMean] * 2.66 * (1 / 3.0) >= 0
                                                         THEN POWER([DayDifferenceTransformedMean] - [DayDifferenceTransformedMovingRangeMean] * 2.66 * (1 / 3.0) , 3.6) END END
      ,[LowerTwoSigma]     = CASE [ChartType] WHEN 'XmR' THEN       [Mean]                         - [MovingRangeMeanForProcessLimits]         * 2.66 * (2 / 3.0)
                                              WHEN 'T'   THEN
                                                    CASE WHEN       [DayDifferenceTransformedMean] - [DayDifferenceTransformedMovingRangeMean] * 2.66 * (2 / 3.0) >= 0
                                                         THEN POWER([DayDifferenceTransformedMean] - [DayDifferenceTransformedMovingRangeMean] * 2.66 * (2 / 3.0) , 3.6) END END
      ,[LowerProcessLimit] = CASE [ChartType] WHEN 'XmR' THEN       [Mean]                         - [MovingRangeMeanForProcessLimits]         * 2.66
                                              WHEN 'T'   THEN
                                                    CASE WHEN       [DayDifferenceTransformedMean] - [DayDifferenceTransformedMovingRangeMean] * 2.66             >= 0
                                                         THEN POWER([DayDifferenceTransformedMean] - [DayDifferenceTransformedMovingRangeMean] * 2.66             , 3.6) END END
INTO #SPCCalculationsProcessLimits
FROM #SPCCalculationsMovingRangeProcessLimit

-- Add upper and lower process limits for baselines
SELECT *
      ,[UpperBaseline] = CASE WHEN [BaselineFlag] = 1 THEN [UpperProcessLimit] END
      ,[LowerBaseline] = CASE WHEN [BaselineFlag] = 1 THEN [LowerProcessLimit] END
INTO #SPCCalculationsBaselineLimits
FROM #SPCCalculationsProcessLimits

-- Update value for T chart
UPDATE bl
SET [Value] = [DayDifference]
FROM #SPCCalculationsBaselineLimits AS bl
WHERE [ChartType] = 'T'

-- Update mean for G chart
UPDATE bl
SET [Mean] = [Mean] * 0.693
FROM #SPCCalculationsBaselineLimits AS bl
WHERE [ChartType] = 'G'

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4e complete, process limits'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4F: SPECIAL CAUSE - SINGLE POINT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for a single point beyond the process limits
--
--====================================================================================================================================================================================================--

-- Add special cause flag for single non-ghosted points beyond upper or lower process limits
SELECT *
      ,[SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag] = CASE WHEN [GhostFlag] = 1               THEN 0
                                                                      WHEN [Value] > [UpperProcessLimit] THEN 1
                                                                                                         ELSE 0 END
      ,[SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag] = CASE WHEN [GhostFlag] = 1               THEN 0
                                                                      WHEN [Value] < [LowerProcessLimit] THEN 1
                                                                                                         ELSE 0 END
INTO #SPCCalculationsSpecialCauseSinglePoint
FROM #SPCCalculationsBaselineLimits

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4f complete, special cause: single point'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4G: SPECIAL CAUSE - SHIFT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for a shift of points all above or below the mean
--
--====================================================================================================================================================================================================--

-- Prepare for special cause flag for a shift of non-ghosted points all above or all below the mean by flagging whether the non-ghosted point is above or below the mean
SELECT *
      ,[SpecialCauseAboveMeanFlag] = CASE WHEN [GhostFlag] = 1  THEN 0
                                          WHEN [Value] > [Mean] THEN 1
                                                                ELSE 0 END
      ,[SpecialCauseBelowMeanFlag] = CASE WHEN [GhostFlag] = 1  THEN 0
                                          WHEN [Value] < [Mean] THEN 1
                                                                ELSE 0 END 
INTO #SPCCalculationsSpecialCauseShiftPrep
FROM #SPCCalculationsSpecialCauseSinglePoint

-- Add cumulative sum of the above and below mean flags for non-ghosted points within metric/group/filter/partition combination
SELECT *
      ,[SpecialCauseAboveMeanPartitionCount] = SUM([SpecialCauseAboveMeanFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date])
      ,[SpecialCauseBelowMeanPartitionCount] = SUM([SpecialCauseBelowMeanFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date])
INTO #SPCCalculationsSpecialCauseShiftPartitionCount
FROM #SPCCalculationsSpecialCauseShiftPrep

-- Determine, depending on setting (set in Step 2a), each non-ghosted point that starts a shift of X non-ghosted points all above or all below the mean within metric/group/filter/partition combination
SELECT *
      ,[SpecialCauseShiftAboveMeanStartFlag] = CASE WHEN [SpecialCauseAboveMeanFlag] = 1
                                                     AND LEAD([SpecialCauseAboveMeanPartitionCount], @SettingSpecialCauseShiftPoints - 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) - [SpecialCauseAboveMeanPartitionCount] = @SettingSpecialCauseShiftPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                                   ELSE 0 END
      ,[SpecialCauseShiftBelowMeanStartFlag] = CASE WHEN [SpecialCauseBelowMeanFlag] = 1
                                                     AND LEAD([SpecialCauseBelowMeanPartitionCount], @SettingSpecialCauseShiftPoints - 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) - [SpecialCauseBelowMeanPartitionCount] = @SettingSpecialCauseShiftPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                                   ELSE 0 END
INTO #SPCCalculationsSpecialCauseShiftStartFlag
FROM #SPCCalculationsSpecialCauseShiftPartitionCount

-- Add cumulative sum of the above and below mean start-of-shift flags for non-ghosted points within metric/group/filter/partition combination
SELECT *
      ,[SpecialCauseShiftAboveMeanStartFlagCount] = SUM([SpecialCauseShiftAboveMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date])
      ,[SpecialCauseShiftBelowMeanStartFlagCount] = SUM([SpecialCauseShiftBelowMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date])
INTO #SPCCalculationsSpecialCauseShiftStartFlagCount
FROM #SPCCalculationsSpecialCauseShiftStartFlag

-- Determine, depending on setting (set in Step 2a), each point within a shift of X non-ghosted points all above or all below the mean
-- This is done by comparing the above/below mean start-of-shift flag count with that X non-ghosted points prior within metric/group/filter/partition combination, replacing NULL for zero when LAG goes back too far
-- [SpecialCauseShiftAboveMeanStartFlagCount] will only be higher if there is at least one point within the last X non-ghosted points within metric/group/filter/partition combination that starts an above/below mean shift
SELECT *
      ,[SpecialCauseRuleShiftAboveMeanFlag] = CASE WHEN [SpecialCauseShiftAboveMeanStartFlagCount] > ISNULL(LAG([SpecialCauseShiftAboveMeanStartFlagCount], @SettingSpecialCauseShiftPoints) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]), 0) THEN 1
                                                                                                                                                                                                                                                                            ELSE 0 END
      ,[SpecialCauseRuleShiftBelowMeanFlag] = CASE WHEN [SpecialCauseShiftBelowMeanStartFlagCount] > ISNULL(LAG([SpecialCauseShiftBelowMeanStartFlagCount], @SettingSpecialCauseShiftPoints) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]), 0) THEN 1
                                                                                                                                                                                                                                                                            ELSE 0 END
INTO #SPCCalculationsSpecialCauseShift
FROM #SPCCalculationsSpecialCauseShiftStartFlagCount

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4g complete, special cause: shift'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4H: SPECIAL CAUSE - TREND
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for a trend increasing or decreasing points, including endpoints, and works across partitions
--
--====================================================================================================================================================================================================--

-- Prepare for special cause flag for a trend of increasing or decreasing non-ghosted points by flagging whether the non-ghosted point is greater than or less than the previous non-ghosted point within metric/group/filter combination
SELECT *
      ,[SpecialCauseIncreasingFlag] = CASE WHEN [GhostFlag] = 1                                                                               THEN 0
                                           WHEN [Value] > LAG([Value], 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Date]) THEN 1
                                                                                                                                              ELSE 0 END
      ,[SpecialCauseDecreasingFlag] = CASE WHEN [GhostFlag] = 1                                                                               THEN 0
                                           WHEN [Value] < LAG([Value], 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Date]) THEN 1
                                                                                                                                              ELSE 0 END
INTO #SPCCalculationsSpecialCauseTrendPrep
FROM #SPCCalculationsSpecialCauseShift

-- Add cumulative sum of the increasing and decreasing flags for non-ghosted points within metric/group/filter combination
SELECT *
      ,[SpecialCauseIncreasingPartitionCount] = SUM([SpecialCauseIncreasingFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Date])
      ,[SpecialCauseDecreasingPartitionCount] = SUM([SpecialCauseDecreasingFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Date])
INTO #SPCCalculationsSpecialCauseTrendPartitionCount
FROM #SPCCalculationsSpecialCauseTrendPrep

-- Determine, depending on setting (set in Step 2a), each non-ghosted point that starts a trend of X increasing or decreasing non-ghosted points within metric/group/filter combination
SELECT *
      ,[SpecialCauseTrendIncreasingStartFlag] = CASE WHEN LEAD([SpecialCauseIncreasingPartitionCount], @SettingSpecialCauseTrendPoints - 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Date]) - [SpecialCauseIncreasingPartitionCount] = @SettingSpecialCauseTrendPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                     ELSE 0 END
      ,[SpecialCauseTrendDecreasingStartFlag] = CASE WHEN LEAD([SpecialCauseDecreasingPartitionCount], @SettingSpecialCauseTrendPoints - 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Date]) - [SpecialCauseDecreasingPartitionCount] = @SettingSpecialCauseTrendPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                     ELSE 0 END
INTO #SPCCalculationsSpecialCauseTrendStartFlag
FROM #SPCCalculationsSpecialCauseTrendPartitionCount

-- Add cumulative sum of the increasing and decreasing start-of-trend flags for non-ghosted points within metric/group/filter combination
SELECT *
      ,[SpecialCauseTrendIncreasingStartFlagCount] = SUM([SpecialCauseTrendIncreasingStartFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Date])
      ,[SpecialCauseTrendDecreasingStartFlagCount] = SUM([SpecialCauseTrendDecreasingStartFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Date])
INTO #SPCCalculationsSpecialCauseTrendStartFlagCount
FROM #SPCCalculationsSpecialCauseTrendStartFlag

-- Determine, depending on setting (set in Step 2a), each non-ghosted point within a trend of X non-ghosted points all increasing or all decreasing, including endpoints
-- This is done by comparing the increasing/decreasing start-of-trend flag count with that X non-ghosted points prior within metric/group/filter combination, replacing NULL for zero when LAG goes back too far
-- [SpecialCauseTrendAboveMeanStartFlagCount] will only be higher if there is at least one point within the last X non-ghosted points within metric/group/filter combination that starts an increasing/decreasing trend
SELECT *
      ,[SpecialCauseRuleTrendIncreasingFlag] = CASE WHEN [SpecialCauseTrendIncreasingStartFlagCount] > ISNULL(LAG([SpecialCauseTrendIncreasingStartFlagCount], @SettingSpecialCauseTrendPoints) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Date]), 0) THEN 1
                                                                                                                                                                                                                                                              ELSE 0 END
      ,[SpecialCauseRuleTrendDecreasingFlag] = CASE WHEN [SpecialCauseTrendDecreasingStartFlagCount] > ISNULL(LAG([SpecialCauseTrendDecreasingStartFlagCount], @SettingSpecialCauseTrendPoints) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Date]), 0) THEN 1
                                                                                                                                                                                                                                                              ELSE 0 END
INTO #SPCCalculationsSpecialCauseTrend
FROM #SPCCalculationsSpecialCauseTrendStartFlagCount

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4h complete, special cause: trend'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4I: SPECIAL CAUSE - TWO-TO-THREE SIGMA
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for there being two or three points within a run of three that lie beyond the two-sigma line but not beyond the three-sigma line (i.e. process limit) on a consistent side of the mean
-- If the third point is not also within this range, it needs to be on the same side of the mean
--
--====================================================================================================================================================================================================--

-- Prepare for special cause flag for two/three of three non-ghosted points within a run of three all beyond two sigma but not beyond three sigma, all on the same side of the mean
SELECT *
      ,[SpecialCauseTwoThreeSigmaAboveMeanFlag] = CASE WHEN [GhostFlag] = 1                THEN 0
                                                       WHEN [Value] > [UpperTwoSigma]
                                                        AND [Value] <= [UpperProcessLimit] THEN 1
                                                                                           ELSE 0 END
      ,[SpecialCauseTwoThreeSigmaBelowMeanFlag] = CASE WHEN [GhostFlag] = 1                THEN 0
                                                       WHEN [Value] < [LowerTwoSigma]
                                                        AND [Value] >= [LowerProcessLimit] THEN 1
                                                                                           ELSE 0 END
INTO #SPCCalculationsSpecialCauseTwoThreeSigmaPrep
FROM #SPCCalculationsSpecialCauseTrend

-- Determine each non-ghosted point that is flagged and starts a group of two or three non-ghosted two-to-three sigma points, all on the same side of the mean, within a run of three, within metric/group/filter/partition combination
-- The third point must also be on the same side of the mean
SELECT *
      ,[SpecialCauseTwoThreeSigmaAboveMeanStartFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaAboveMeanFlag] = 1
                                                             AND ( LEAD([SpecialCauseTwoThreeSigmaAboveMeanFlag], 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) = 1
                                                              AND ( LAG([SpecialCauseAboveMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) = 1
                                                               OR (LEAD([SpecialCauseAboveMeanFlag], 2)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) = 1))
                                                             OR    LEAD([SpecialCauseTwoThreeSigmaAboveMeanFlag], 2) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) = 1
                                                              AND  LEAD([SpecialCauseAboveMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) = 1)  THEN 1
                                                                                                                                                                                                      ELSE 0 END
      ,[SpecialCauseTwoThreeSigmaBelowMeanStartFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaBelowMeanFlag] = 1
                                                             AND ( LEAD([SpecialCauseTwoThreeSigmaBelowMeanFlag], 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) = 1
                                                              AND ( LAG([SpecialCauseBelowMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) = 1
                                                               OR (LEAD([SpecialCauseBelowMeanFlag], 2)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) = 1))
                                                             OR    LEAD([SpecialCauseTwoThreeSigmaBelowMeanFlag], 2) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) = 1
                                                              AND  LEAD([SpecialCauseBelowMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]) = 1)  THEN 1
                                                                                                                                                                                                      ELSE 0 END
INTO #SPCCalculationsSpecialCauseTwoThreeSigmaStartFlag
FROM #SPCCalculationsSpecialCauseTwoThreeSigmaPrep

-- Add cumulative sum of the above and below mean start-of-two-to-three-sigma flags for non-ghosted points within metric/group/filter/partition combination
SELECT *
      ,[SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount] = SUM([SpecialCauseTwoThreeSigmaAboveMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date])
      ,[SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount] = SUM([SpecialCauseTwoThreeSigmaBelowMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date])
INTO #SPCCalculationsSpecialCauseTwoThreeSigmaStartFlagCount
FROM #SPCCalculationsSpecialCauseTwoThreeSigmaStartFlag

-- Determine each non-ghosted two-to-three sigma point within a group of two or three non-ghosted two-to-three sigma points, on the same side of the mean
-- This is done by comparing the above/below mean start-of-two-to-three sigma flag count with that 3 non-ghosted points prior within metric/group/filter/partition combination, replacing NULL for zero when LAG goes back too far
-- [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount] will only be higher if there is at least one point within the last 2 non-ghosted points within metric/group/filter/partition combination that starts a new group
-- The point itself must also be flagged
SELECT *
      ,[SpecialCauseRuleTwoThreeSigmaAboveMeanFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaAboveMeanFlag] = 1
                                                            AND [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount] > ISNULL(LAG([SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount], 3) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]), 0) THEN 1
                                                                                                                                                                                                                                                                      ELSE 0 END
      ,[SpecialCauseRuleTwoThreeSigmaBelowMeanFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaBelowMeanFlag] = 1
                                                            AND [SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount] > ISNULL(LAG([SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount], 3) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Date]), 0) THEN 1
                                                                                                                                                                                                                                                                      ELSE 0 END
INTO #SPCCalculationsSpecialCauseTwoThreeSigma
FROM #SPCCalculationsSpecialCauseTwoThreeSigmaStartFlagCount

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4i complete, special cause: two-to-three sigma'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4J: SPECIAL CAUSE COMBINED
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step combines the points that have triggered special cause rules
--
--====================================================================================================================================================================================================--

-- Combine special cause rules into improvement/concern/neither values
-- Add conflict flag for updating below
-- Add neither high/low flags
SELECT *
      ,[SpecialCauseImprovementValue] = CASE WHEN [MetricImprovement] = 'Up'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1) THEN [Value]
                                             WHEN [MetricImprovement] = 'Down'
                                              AND ([SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN [Value] END
      ,[SpecialCauseConcernValue]     = CASE WHEN [MetricImprovement] = 'Up'
                                              AND ([SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN [Value]
                                             WHEN [MetricImprovement] = 'Down'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1) THEN [Value] END
      ,[SpecialCauseConflictFlag]      = NULL
      ,[SpecialCauseNeitherValue]      = CASE WHEN [MetricImprovement] = 'Neither'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag] = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN [Value] END
      ,[SpecialCauseNeitherHighFlag]  = CASE WHEN [MetricImprovement] = 'Neither'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1) THEN 1
                                                                                                                   ELSE 0 END
      ,[SpecialCauseNeitherLowFlag]   = CASE WHEN [MetricImprovement] = 'Neither'
                                              AND ([SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN 1
                                                                                                                   ELSE 0 END
INTO #SPCCalculationsSpecialCauseCombined
FROM #SPCCalculationsSpecialCauseTwoThreeSigma

-- For points that have triggered both an improvement rule and a concern rule, for example an ascending trend below the mean, remove one depending on [MetricConflict] and update conflicting flag:
-- Show only as improvement by removing concern value...
UPDATE #SPCCalculationsSpecialCauseCombined
SET [SpecialCauseConcernValue] = NULL
   ,[SpecialCauseConflictFlag] = 1
WHERE [MetricConflictRule] = 'Improvement'
  AND [SpecialCauseImprovementValue] IS NOT NULL
  AND [SpecialCauseConcernValue]     IS NOT NULL

-- ...or show only as concern by removing improvement value
UPDATE #SPCCalculationsSpecialCauseCombined
SET [SpecialCauseImprovementValue] = NULL
   ,[SpecialCauseConflictFlag]     = 1
WHERE [MetricConflictRule] = 'Concern'
  AND [SpecialCauseImprovementValue] IS NOT NULL
  AND [SpecialCauseConcernValue]     IS NOT NULL

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4j complete, special cause combined'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4K: ICONS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds the variation and assurance icons for the last non-ghosted point
-- Variation icon is added for the last non-ghosted point if an up/down metric improvement is provided
-- Assurance icon is added for the last non-ghosted point if an up/down metric improvement and target are both provided
--
--====================================================================================================================================================================================================--

-- Add variance and assurance icon flags for XmR charts
SELECT *
      ,[IconID]        = CASE WHEN [PointExcludeGhostingRankDescending] = 1                                   THEN CONCAT([MetricID], '||', [GroupHierarchy], '||', [Group], '||', ISNULL([Filter1], '< No Filter >'), '||', ISNULL([Filter2], '< No Filter >')) END
      ,[VariationIcon] = CASE WHEN [PointExcludeGhostingRankDescending] = 1                                   THEN CASE WHEN [MetricImprovement] = 'Up'      THEN CASE WHEN [SpecialCauseImprovementValue] IS NOT NULL THEN 'Improvement (High)'
                                                                                                                                                                       WHEN [SpecialCauseConcernValue]     IS NOT NULL THEN 'Concern (Low)'
                                                                                                                                                                                                                       ELSE 'Common Cause' END
                                                                                                                        WHEN [MetricImprovement] = 'Down'    THEN CASE WHEN [SpecialCauseImprovementValue] IS NOT NULL THEN 'Improvement (Low)'
                                                                                                                                                                       WHEN [SpecialCauseConcernValue]     IS NOT NULL THEN 'Concern (High)'
                                                                                                                                                                                                                       ELSE 'Common Cause' END
                                                                                                                        WHEN [MetricImprovement] = 'Neither' THEN CASE WHEN [SpecialCauseNeitherHighFlag] = 1          THEN 'Neither (High)'
                                                                                                                                                                       WHEN [SpecialCauseNeitherLowFlag]  = 1          THEN 'Neither (Low)'
                                                                                                                                                                                                                       ELSE 'Common Cause' END END END
      ,[AssuranceIcon] = CASE WHEN [PointExcludeGhostingRankDescending] = 1 AND [ChartType] NOT IN ('T', 'G') THEN CASE WHEN [MetricImprovement] = 'Up'      THEN CASE WHEN [Target] <= [LowerProcessLimit]            THEN 'Pass'
                                                                                                                                                                       WHEN [Target] >  [LowerProcessLimit]                
                                                                                                                                                                        AND [Target] <  [UpperProcessLimit]            THEN 'Hit or Miss'
                                                                                                                                                                       WHEN [Target] >= [UpperProcessLimit]            THEN 'Fail' END
                                                                                                                        WHEN [MetricImprovement] = 'Down'    THEN CASE WHEN [Target] >= [UpperProcessLimit]            THEN 'Pass'
                                                                                                                                                                       WHEN [Target] >  [LowerProcessLimit]                
                                                                                                                                                                        AND [Target] <  [UpperProcessLimit]            THEN 'Hit or Miss'
                                                                                                                                                                       WHEN [Target] <= [LowerProcessLimit]            THEN 'Fail' END END END
INTO #SPCCalculationsIcons
FROM #SPCCalculationsSpecialCauseCombined

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4k complete, icons'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4L: ROW COUNT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds row counts for use in Steps 5-6
--
--====================================================================================================================================================================================================--

-- Add row counts to enable possible exclusion of metric/group/filter combinations with an insufficient number of points (set in Step 2b)
SELECT *
      ,[RowCountExcludeGhosting] = SUM(CASE WHEN [GhostFlag] = 1 THEN 0
                                            WHEN [PointRank] = 0 THEN 0
                                                                 ELSE 1 END) OVER(PARTITION BY [ChartID])
INTO #SPCCalculationsRowCount
FROM #SPCCalculationsIcons

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4l complete, row count'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 5: WARNINGS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step, if set to run, checks for various warnings and outputs the results
--
--====================================================================================================================================================================================================--

-- Checks for setting (set in Step 2b)
IF @SettingGlobalWarnings = 1

    BEGIN

        -- Create temporary table
        CREATE TABLE #Warnings (
                                 [Warning] NVARCHAR(MAX) NOT NULL
                                ,[Detail]  NVARCHAR(MAX) NOT NULL
                               )

        -- Check warnings listed in Step 2a
        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '@SettingSpecialCauseShiftPoints is set to a value less than 6'
              ,[Detail]  = CONCAT('@SettingSpecialCauseShiftPoints = ', @SettingSpecialCauseShiftPoints)
        WHERE @SettingSpecialCauseShiftPoints < 6

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '@SettingSpecialCauseShiftPoints is set to a value greater than 8'
              ,[Detail]  = CONCAT('@SettingSpecialCauseShiftPoints = ', @SettingSpecialCauseShiftPoints)
        WHERE @SettingSpecialCauseShiftPoints > 8

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '@SettingSpecialCauseTrendPoints is set to a value less than 6'
              ,[Detail]  = CONCAT('@SettingSpecialCauseTrendPoints = ', @SettingSpecialCauseTrendPoints)
        WHERE @SettingSpecialCauseTrendPoints < 6

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '@SettingSpecialCauseTrendPoints is set to a value greater than 8'
              ,[Detail]  = CONCAT('@SettingSpecialCauseTrendPoints = ', @SettingSpecialCauseTrendPoints)
        WHERE @SettingSpecialCauseTrendPoints > 8

        -- Check warnings listed in Step 2b
        INSERT INTO #Warnings
        SELECT [Warning] = CONCAT('Fewer than ', @SettingMinimumPoints, ' non-ghosted points so displayed as a run chart')
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; number of non-ghosted points = ', [Non-Ghosted Point Count])
        FROM (
               SELECT DISTINCT
                      [MetricID]
                     ,[Group]
                     ,[Filter1]
                     ,[Filter2]
                     ,[Non-Ghosted Point Count] = SUM(CASE WHEN [GhostFlag] = 1 THEN 0
                                                                                ELSE 1 END) OVER(PARTITION BY [ChartID])
               FROM #SPCCalculationsRowCount
             ) t
        WHERE @SettingMinimumPointsWarning = 1
          AND [Non-Ghosted Point Count] < @SettingMinimumPoints

        INSERT INTO #Warnings
        SELECT [Warning] = CONCAT('Fewer than ', @SettingMinimumPointsPartition, ' non-ghosted points in partition')
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [PartitionID] = ', '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), [PartitionID], '; number of non-ghosted points = ', [Partition Non-Ghosted Point Count])
        FROM (
               SELECT DISTINCT
                      [MetricID]
                     ,[Group]
                     ,[Filter1]
                     ,[Filter2]
                     ,[PartitionID]
                     ,[Chart Non-Ghosted Point Count]     = SUM(CASE WHEN [GhostFlag] = 1 THEN 0
                                                                                          ELSE 1 END) OVER(PARTITION BY [ChartID])
                     ,[Partition Non-Ghosted Point Count] = SUM(CASE WHEN [GhostFlag] = 1 THEN 0
                                                                                          ELSE 1 END) OVER(PARTITION BY [ChartID], [PartitionID])
               FROM #SPCCalculationsRowCount
             ) t
        WHERE [Partition Non-Ghosted Point Count] < @SettingMinimumPointsPartition
          AND [Chart Non-Ghosted Point Count] >= @SettingMinimumPoints

        INSERT INTO #Warnings
        SELECT [Warning] = CONCAT('Over ', @SettingMaximumPointsPartition, ' non-ghosted points in partition')
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [PartitionID] = ', [PartitionID], '; number of non-ghosted points = ', [Non-Ghosted Point Count])
        FROM (
               SELECT DISTINCT
                      [MetricID]
                     ,[Group]
                     ,[Filter1]
                     ,[Filter2]
                     ,[PartitionID]
                     ,[Non-Ghosted Point Count] = SUM(CASE WHEN [GhostFlag] = 1 THEN 0
                                                                                ELSE 1 END) OVER(PARTITION BY [ChartID], [PartitionID])
               FROM #SPCCalculationsRowCount
             ) t
        WHERE [Non-Ghosted Point Count] > @SettingMaximumPointsPartition

        INSERT INTO #Warnings
        SELECT [Warning] = CONCAT('Over ', @SettingMaximumPoints, ' points in chart (too many to be displayed in a chart)')
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; number of points = ', [Point Count])
        FROM (
               SELECT DISTINCT
                      [MetricID]
                     ,[Group]
                     ,[Filter1]
                     ,[Filter2]
                     ,[Point Count] = COUNT(*) OVER(PARTITION BY [ChartID])
               FROM #SPCCalculationsRowCount
             ) t
        WHERE [Point Count] > @SettingMaximumPoints

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Improvement/concern conflict affecting point'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [Date] = ', CONVERT(VARCHAR, [Date], 121), '; [MetricConflictRule] = ', [MetricConflictRule])
        FROM #SPCCalculationsRowCount
        WHERE @SettingPointConflictWarning = 1
          AND [RowCountExcludeGhosting] >= @SettingMinimumPoints
          AND [SpecialCauseConflictFlag] = 1

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Improvement/concern conflict affecting variation icon'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [MetricConflictRule] = ', [MetricConflictRule])
        FROM #SPCCalculationsRowCount
        WHERE @SettingVariationIconConflictWarning = 1
          AND [RowCountExcludeGhosting] >= @SettingMinimumPoints
          AND [SpecialCauseConflictFlag] = 1
          AND [IconID] IS NOT NULL
    
        -- Check warnings listed in Step 3a
        INSERT INTO #Warnings
        SELECT [Warning] = '[MetricOrder] is duplicated'
              ,[Detail]  = CONCAT('[MetricOrder] = ', [MetricOrder], '; ', COUNT(*), ' records')
        FROM #MetricData
        GROUP BY [MetricOrder]
        HAVING COUNT(*) > 1

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[MetricID] excluded: exists in #MetricData but not in #RawData'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID])
        FROM #MetricData
        WHERE [MetricID] NOT IN (SELECT [MetricID]
                                 FROM #RawData)

        INSERT INTO #Warnings
        SELECT [Warning] = '[MetricID] is duplicated'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; ', COUNT(*), ' records')
        FROM #MetricData
        GROUP BY [MetricID]
        HAVING COUNT(*) > 1

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[ChartType] is not a valid option (''XmR'', ''T'', or ''G'')'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [ChartType] = ', [ChartType])
        FROM #MetricData
        WHERE [ChartType] NOT IN ('XmR', 'T', 'G')

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[MetricImprovement] is not a valid option (''Up'', ''Down'', or ''Neither'')'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [MetricImprovement] = ', [MetricImprovement])
        FROM #MetricData
        WHERE [MetricImprovement] NOT IN ('Up', 'Down', 'Neither')

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[MetricConflictRule] is not a valid option (''Improvement'' or ''Concern'')'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [MetricConflictRule] = ', ISNULL([MetricConflictRule], 'NULL'))
        FROM #MetricData
        WHERE [MetricImprovement] IN ('Up', 'Down')
          AND ISNULL([MetricConflictRule], 'NULL') NOT IN ('Improvement', 'Concern')
          AND [ChartTitle] = 'XmR'

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[DateFormat] is not a valid option (''dd/MM/yy'', ''dd/MM/yyyy'', ''MMM yy'')'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [DateFormat] = ', [DateFormat])
        FROM #MetricData
        WHERE [DateFormat] NOT IN ('d/M/yy', 'd/M/yyyy', 'dd/MM/yy', 'dd/MM/yyyy', 'd MMM yy', 'd MMM yyyy', 'd MMMM yy', 'd MMMM yyyy', 'dd MMM yy', 'dd MMM yyyy', 'dd MMMM yy', 'dd MMMM yyyy', 'MMM yy', 'MMM yyyy', 'MMMM yy', 'MMMM yyyy', 'yyyy-MM', 'yyyy-MM-dd')
        
        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[MetricFormat] is not a valid option (''General'', ''Percentage'' or ''Time'')'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [MetricFormat] = ', [MetricFormat])
        FROM #MetricData
        WHERE [MetricImprovement] IN ('Up', 'Down')
          AND ISNULL([MetricFormat], 'NULL') NOT IN ('General', 'Percentage', 'Time')

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[MetricFormat] is not ''General'' and [ChartType] is ''T'' or ''G'''
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [MetricFormat] = ', [MetricFormat], '; [ChartType] = ', [ChartType])
        FROM #MetricData
        WHERE [MetricFormat] <> 'General'
          AND [ChartType] IN ('T', 'G')

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[VerticalAxisMinFix] and [VerticalAxisMinFlex] both provided'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [VerticalAxisMinFix] = ', [VerticalAxisMinFix], '; [VerticalAxisMinFlex] = ', [VerticalAxisMinFlex])
        FROM #MetricData
        WHERE [VerticalAxisMinFix]  IS NOT NULL
          AND [VerticalAxisMinFlex] IS NOT NULL

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[VerticalAxisMaxFix] and [VerticalAxisMaxFlex] both provided'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [VerticalAxisMaxFix] = ', [VerticalAxisMaxFix], '; [VerticalAxisMaxFlex] = ', [VerticalAxisMaxFlex])
        FROM #MetricData
        WHERE [VerticalAxisMaxFix]  IS NOT NULL
          AND [VerticalAxisMaxFlex] IS NOT NULL

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[VerticalAxisMinFix] or [VerticalAxisMinFlex] is not less than [VerticalAxisMaxFix] or [VerticalAxisMaxFlex]'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [VerticalAxisMinFix] = ', [VerticalAxisMinFix], '; [VerticalAxisMinFlex] = ', [VerticalAxisMinFlex], '; [VerticalAxisMaxFix] = ', [VerticalAxisMaxFix], '; [VerticalAxisMaxFlex] = ', [VerticalAxisMaxFlex])
        FROM #MetricData
        WHERE [VerticalAxisMinFix]  >= [VerticalAxisMaxFix]
           OR [VerticalAxisMinFix]  >= [VerticalAxisMaxFlex]
           OR [VerticalAxisMinFlex] >= [VerticalAxisMaxFix]
           OR [VerticalAxisMinFlex] >= [VerticalAxisMaxFlex]

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[LowMeanWarningValue] is provided and [ChartType] is ''T'' or ''G'''
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [ChartType] = ', [ChartType], '; [LowMeanWarningValue] = ', [LowMeanWarningValue])
        FROM #MetricData
        WHERE [LowMeanWarningValue] IS NOT NULL
          AND [ChartType] IN ('T', 'G')

        INSERT INTO #Warnings
        SELECT [Warning] = CONCAT('Mean is less than ', LowMeanWarningValue)
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [PartitionID] = ', [PartitionID], '; [Mean] = ', [Mean])
        FROM (
               SELECT DISTINCT
                      [MetricID]
                     ,[Group]
                     ,[Filter1]
                     ,[Filter2]
                     ,[PartitionID]
                     ,[Non-Ghosted Point Count] = SUM(CASE WHEN [GhostFlag] = 1 THEN 0
                                                                                ELSE 1 END) OVER(PARTITION BY [ChartID])
                     ,[LowMeanWarningValue]
                     ,[Mean]
               FROM #SPCCalculationsRowCount
             ) t
        WHERE [Mean] < [LowMeanWarningValue]
          AND [Non-Ghosted Point Count] >= @SettingMinimumPoints

        -- Check warnings listed in Step 3b
        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[MetricID] excluded: exists in #RawData but not in #MetricData'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID])
        FROM #RawData
        WHERE [MetricID] NOT IN (SELECT [MetricID]
                                 FROM #MetricData)

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[GroupParent] exists in #RawData but not as a [Group]'
              ,[Detail]  = CONCAT('[GroupParent] = ', r.[GroupParent])
        FROM #RawData AS r
        WHERE [GroupParent] IS NOT NULL
          AND [GroupParent] NOT IN (SELECT [Group]
                                    FROM #RawData)

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[Group] excluded; check [GroupParent] hierarchy is not in a loop'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group])
        FROM #RawData
        WHERE CONCAT([MetricID], '||', [Group]) NOT IN (SELECT CONCAT([MetricID], '||', [Group])
                                                        FROM #SPCCalculationsRowCount)

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Multiple [GroupParent] values provided for same [Group]'
              ,[Detail]  = CONCAT('[Group] = ', [Group], '; [GroupParent] values = ', STUFF((SELECT DISTINCT ' | ' + ISNULL([GroupParent], 'NULL')
                                                                                             FROM #RawData AS t2
                                                                                             WHERE t2.[Group] = t1.[Group]
                                                                                             FOR XML PATH('')), 1, 3, ''))
        FROM #RawData AS t1
        GROUP BY [Group]
        HAVING(COUNT(DISTINCT ISNULL([GroupParent], 'NULL'))) > 1

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Multiple [GroupHierarchyOrder] values provided for same [Group]'
              ,[Detail]  = CONCAT('[Group] = ', [Group], '; [GroupHierarchyOrder] values = ', STUFF((SELECT DISTINCT ' | ' + ISNULL(CAST([GroupHierarchyOrder] AS NVARCHAR(MAX)), 'NULL')
                                                                                                     FROM #RawData AS t2
                                                                                                     WHERE t2.[Group] = t1.[Group]
                                                                                                     FOR XML PATH('')), 1, 3, ''))
        FROM #RawData AS t1
        GROUP BY [Group]
        HAVING(COUNT(DISTINCT ISNULL(CAST([GroupHierarchyOrder] AS NVARCHAR(MAX)), 'NULL'))) > 1

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[MetricID], [Group], [Filter1], and [Filter2] concatenation includes ''||'' delimiter'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'))
        FROM #RawData AS r
        WHERE CONCAT([MetricID], [Group], [Filter1], [Filter2]) LIKE '%||%'

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[Filter1] is ''< No Filter >'''
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [Date] = ', CONVERT(VARCHAR, [Date], 121))
        FROM #RawData
        WHERE [Filter1] = '< No Filter >'

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[Filter2] is ''< No Filter >'''
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Date] = ', CONVERT(VARCHAR, [Date], 121))
        FROM #RawData
        WHERE [Filter2] = '< No Filter >'

        INSERT INTO #Warnings
        SELECT [Warning] = '[Date] is duplicated'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [Date] = ', CONVERT(VARCHAR, [Date], 121), '; ', COUNT(*), ' records')
        FROM #RawData
        GROUP BY [MetricID]
                ,[Group]
                ,[Filter1]
                ,[Filter2]
                ,[Date]
        HAVING COUNT(*) > 1

        INSERT INTO #Warnings
        SELECT [Warning] = '[Date] is duplicated with [DateFormat] selected'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [Date] = ', FORMAT([Date], [DateFormat]), '; ', COUNT(*), ' records')
        FROM #SPCCalculationsRowCount
        GROUP BY [MetricID]
                ,[Group]
                ,[Filter1]
                ,[Filter2]
                ,FORMAT([Date], [DateFormat])
        HAVING COUNT(*) > 1

        INSERT INTO #Warnings
        SELECT [Warning] = '[Value] is not provided and [ChartType] is ''XmR'' or ''G'''
              ,[Detail]  = CONCAT('[MetricID] = ', m.[MetricID], '; [ChartType] = ', m.[ChartType], '; [Group] = ', r.[Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [Date] = ', CONVERT(VARCHAR, r.[Date], 121))
        FROM #RawData          AS r
        INNER JOIN #MetricData AS m ON m.[MetricID] = r.[MetricID]
        WHERE r.[Value] IS NULL
          AND m.[ChartType] IN ('XmR', 'G')

        INSERT INTO #Warnings
        SELECT [Warning] = '[Value] is provided and [ChartType] is ''T'''
              ,[Detail]  = CONCAT('[MetricID] = ', m.[MetricID], '; [Group] = ', r.[Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [Date] = ', CONVERT(VARCHAR, r.[Date], 121), '; [Value] = ', r.[Value])
        FROM #RawData          AS r
        INNER JOIN #MetricData AS m ON m.[MetricID] = r.[MetricID]
        WHERE r.[Value] IS NOT NULL
          AND m.[ChartType] = 'T'

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[RecalculateLimitsFlag] is not a valid option (1 or 0)'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [RecalculateLimitsFlag] = ', [RecalculateLimitsFlag])
        FROM #RawData
        WHERE [RecalculateLimitsFlag] NOT IN (1, 0)

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Recalculation of limits within baseline'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [Date] = ', CONVERT(VARCHAR, [Date], 121))
        FROM #SPCCalculationsRowCount
        WHERE [RecalculateLimitsFlag] = 1
          AND [BaselineFlag] = 1

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[GhostFlag] is not a valid option (1 or 0)'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [GhostFlag] = ', [GhostFlag])
        FROM #RawData
        WHERE [GhostFlag] NOT IN (1, 0)

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = '[GhostFlag] ''1'' and [ChartType] is ''T'' or ''G'''
              ,[Detail]  = CONCAT('[MetricID] = ', m.[MetricID], '; [ChartType] = ', m.[ChartType], '; [Group] = ', r.[Group], '; [Filter1] = ', ISNULL([Filter1], '< No Filter >'), '; [Filter2] = ', ISNULL([Filter2], '< No Filter >'), '; [Date] = ', CONVERT(VARCHAR, r.[Date], 121))
        FROM #RawData          AS r
        INNER JOIN #MetricData AS m ON m.[MetricID] = r.[MetricID]
        WHERE r.[GhostFlag] = 1
          AND m.[ChartType] IN ('T', 'G')

        -- Check warnings listed in Step 3c
        INSERT INTO #Warnings
        SELECT [Warning] = '[BaselineOrder] is duplicated'
              ,[Detail]  = CONCAT('[BaselineOrder] = ', [BaselineOrder], '; ', COUNT(*), ' records')
        FROM #BaselineData
        GROUP BY [BaselineOrder]
        HAVING COUNT(*) > 1

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Baseline excluded: [MetricID] exists in #BaselineData but not in #MetricData and/or #RawData'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID])
        FROM #BaselineData
        WHERE [MetricID] NOT IN (SELECT [MetricID]
                                 FROM #MetricData

                                 INTERSECT

                                 SELECT [MetricID]
                                 FROM #RawData)

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Baseline excluded: [Group] exists in #BaselineData but not in #RawData'
              ,[Detail]  = CONCAT('[MetricID] = ', b.[MetricID], '; [Group] = ', b.[Group])
        FROM #BaselineData AS b
        WHERE [Group] NOT IN (SELECT [Group]
                              FROM #RawData
                              WHERE [MetricID] = b.[MetricID])

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Baseline excluded: [Date] exists in #BaselineData but not in #RawData'
              ,[Detail]  = CONCAT('[MetricID] = ', b.[MetricID], '; [Group] = ', b.[Group], '; [Date] = ', CONVERT(VARCHAR, b.[Date], 121))
        FROM #BaselineData AS b
        WHERE b.[Date] NOT IN (SELECT [Date]
                               FROM #RawData
                               WHERE [MetricID] = b.[MetricID]
                                 AND [Group] = b.[Group])
          AND b.[Group] IS NOT NULL

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Baseline excluded: [Date] exists in #BaselineData but not in #RawData (for at least one group)'
              ,[Detail]  = CONCAT('[MetricID] = ', b.[MetricID], '; [Group] = NULL; [Date] = ', CONVERT(VARCHAR, b.[Date], 121))
        FROM #BaselineData AS b
        WHERE b.[Date] NOT IN (SELECT [Date]
                               FROM #RawData
                               WHERE [MetricID] = b.[MetricID])
          AND b.[Group] IS NULL

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Baseline excluded: multiple baselines provided'
              ,[Detail]  = CONCAT('[MetricID] = ', b1.[MetricID], '; [Group] = ', b1.[Group], '; baseline used: [Date] = ', CONVERT(VARCHAR, b1.[Date], 121), ', [PointsExcludeGhosting] = ', b1.[PointExcludeGhostingRankAscending], '; baseline not used: [Date] = ', CONVERT(VARCHAR, b2.[Date], 121), ', [PointsExcludeGhosting] = ', b2.[PointExcludeGhostingRankAscending])
        FROM #SPCCalculationsBaseline       AS b1
        INNER JOIN #SPCCalculationsBaseline AS b2 ON b2.[MetricID] = b1.[MetricID]
                                                 AND b2.[Group] = b1.[Group]
                                                 AND b2.[BaselineEndRank] > 1
        WHERE b1.[BaselineEndRank] = 1

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Baseline includes special cause variation'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', [Group])
        FROM #SPCCalculationsRowCount
        WHERE [PartitionID] = 0
          AND ([SpecialCauseImprovementValue] IS NOT NULL
            OR [SpecialCauseConcernValue]     IS NOT NULL
            OR [SpecialCauseNeitherValue]     IS NOT NULL)

        -- Check warnings listed in Step 3d
        INSERT INTO #Warnings
        SELECT [Warning] = '[TargetOrder] is duplicated'
              ,[Detail]  = CONCAT('[TargetOrder] = ', [TargetOrder], '; ', COUNT(*), ' records')
        FROM #TargetData
        GROUP BY [TargetOrder]
        HAVING COUNT(*) > 1

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Target excluded: [MetricID] exists in #TargetData but not in #MetricData and/or #RawData'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID])
        FROM #TargetData
        WHERE [MetricID] NOT IN (SELECT [MetricID]
                                 FROM #MetricData

                                 INTERSECT

                                 SELECT [MetricID]
                                 FROM #RawData)

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Target excluded: [Group] exists in #TargetData but not in #RawData'
              ,[Detail]  = CONCAT('[MetricID] = ', t.[MetricID], '; [Group] = ', t.[Group])
        FROM #TargetData AS t
        WHERE [Group] NOT IN (SELECT [Group]
                              FROM #RawData
                              WHERE [MetricID] = t.[MetricID])

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Target excluded: [StartDate] is after [EndDate]'
              ,[Detail]  = CONCAT('[MetricID] = ', [MetricID], '; [Group] = ', ISNULL([Group], 'NULL'), '; [StartDate] = ', [StartDate], '; [EndDate] = ', [EndDate])
        FROM #TargetData
        WHERE [StartDate] > [EndDate]

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Target excluded: multiple targets provided'
              ,[Detail]  = CONCAT('[MetricID] = ', t1.[MetricID], '; [Group] = ', t1.[Group], '; [Date] = ', CONVERT(VARCHAR, t1.[Date], 121), '; target used = ', t1.[Target], '; target not used = ', t2.[Target])
        FROM #SPCCalculationsAllTargets       AS t1
        INNER JOIN #SPCCalculationsAllTargets AS t2 ON t2.[RowID] = t1.[RowID]
                                                   AND t2.[TargetRank] > 1
        WHERE t1.[TargetRank] = 1

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Target excluded: [MetricImprovement] is not ''Up'' or ''Down'''
              ,[Detail]  = CONCAT('[MetricID] = ',t.[MetricID], '; [MetricImprovement] = ', m.[MetricImprovement])
        FROM #TargetData       AS t
        INNER JOIN #MetricData AS m ON m.[MetricID] = t.[MetricID]
        WHERE m.[MetricImprovement] NOT IN ('Up', 'Down')

        INSERT INTO #Warnings
        SELECT DISTINCT
               [Warning] = 'Target excluded: [ChartType] is ''T'' or ''G'''
              ,[Detail]  = CONCAT('[MetricID] = ',t.[MetricID], '; [ChartType] = ', m.[ChartType])
        FROM #TargetData       AS t
        INNER JOIN #MetricData AS m ON m.[MetricID] = t.[MetricID]
        WHERE m.[ChartType] IN ('T', 'G')

        -- Return warning messages
        SELECT *
        FROM #Warnings

        -- Print message for end of step
        SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 5  complete, warnings'
        RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

    END

ELSE

    BEGIN

        -- Print message for end of step
        SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 5  skipped, warnings'
        RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

    END

--====================================================================================================================================================================================================--
-- STEP 6: OUTPUT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is unless used with the accompanying Power BI template
-- Either store the output in a table (see commented out code below) or turn this SQL query into a stored procedure and skip the warning step above so that only one table is returned
--
-- This step returns the table that is used in the accompanying Power BI template
-- Removing any of these columns may result in the tool not working correctly
-- Additional columns can be added for information purposes
--
--====================================================================================================================================================================================================--

-- Columns removed and reordered
-- SPC features removed from chart for metric/group/filter combinations with an insufficient number of points, depending on setting (set in Step 2b)
SELECT [RowID]
      ,[ChartID]
      ,[IconID]
      ,[PointRank]
      ,[MetricOrder]
      ,[MetricID]
      ,[MetricName]
      ,[ChartType]
      ,[DateFormat]
      ,[MetricFormat]
      ,[ChartTitle]
      ,[HorizontalAxisTitle]
      ,[VerticalAxisTitle]
      ,[VerticalAxisMinFix]
      ,[VerticalAxisMinFlex]
      ,[VerticalAxisMaxFix]
      ,[VerticalAxisMaxFlex]
      ,[GroupOrder]
      ,[GroupHierarchy]
      ,[GroupName]
      ,[Filter1]
      ,[Filter2]
      ,[Date]
      ,[Value]
      ,[Target]
      ,[Mean]
      ,[MovingRange]
      ,[MovingRangeMean]
      ,[MovingRangeProcessLimit]      = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [MovingRangeProcessLimit]      END
      ,[MovingRangeHighPointValue]    = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [MovingRangeHighPointValue]    END
      ,[UpperBaseline]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [UpperBaseline]                END
      ,[UpperProcessLimit]            = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [UpperProcessLimit]            END
      ,[UpperTwoSigma]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [UpperTwoSigma]                END
      ,[UpperOneSigma]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [UpperOneSigma]                END
      ,[LowerOneSigma]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [LowerOneSigma]                END
      ,[LowerTwoSigma]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [LowerTwoSigma]                END
      ,[LowerProcessLimit]            = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [LowerProcessLimit]            END
      ,[LowerBaseline]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [LowerBaseline]                END
      ,[GhostValue]                   = CASE WHEN [GhostFlag]                = 1                     THEN [Value]                        END
      ,[SpecialCauseImprovementValue] = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [SpecialCauseImprovementValue] END
      ,[SpecialCauseConcernValue]     = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [SpecialCauseConcernValue]     END
      ,[SpecialCauseNeitherValue]     = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [SpecialCauseNeitherValue]     END
      ,[VariationIcon]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [VariationIcon]                END
      ,[AssuranceIcon]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [AssuranceIcon]                END
      ,[Annotation]
--INTO [DatabaseName].[SchemaName].[TableName]
FROM #SPCCalculationsRowCount
WHERE [PointRank] > 0
ORDER BY [MetricOrder]
        ,[GroupOrder]
        ,[Filter1]
        ,[Filter2]
        ,[Date]

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 6  complete, output'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 7: CLEAR-UP
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step drops the temporary tables that were used
--
--====================================================================================================================================================================================================--

-- Remove temporary tables
IF OBJECT_ID('tempdb..#MetricData')                                             IS NOT NULL DROP TABLE #MetricData
IF OBJECT_ID('tempdb..#RawData')                                                IS NOT NULL DROP TABLE #RawData
IF OBJECT_ID('tempdb..#BaselineData')                                           IS NOT NULL DROP TABLE #BaselineData
IF OBJECT_ID('tempdb..#TargetData')                                             IS NOT NULL DROP TABLE #TargetData
IF OBJECT_ID('tempdb..#SPCCalculationsDistinctGroups')                          IS NOT NULL DROP TABLE #SPCCalculationsDistinctGroups
IF OBJECT_ID('tempdb..#SPCCalculationsHierarchy')                               IS NOT NULL DROP TABLE #SPCCalculationsHierarchy
IF OBJECT_ID('tempdb..#SPCCalculationsPartition')                               IS NOT NULL DROP TABLE #SPCCalculationsPartition
IF OBJECT_ID('tempdb..#SPCCalculationsBaselineFlag')                            IS NOT NULL DROP TABLE #SPCCalculationsBaselineFlag
IF OBJECT_ID('tempdb..#SPCCalculationsBaseline')                                IS NOT NULL DROP TABLE #SPCCalculationsBaseline
IF OBJECT_ID('tempdb..#SPCCalculationsAllTargets')                              IS NOT NULL DROP TABLE #SPCCalculationsAllTargets
IF OBJECT_ID('tempdb..#SPCCalculationsSingleTarget')                            IS NOT NULL DROP TABLE #SPCCalculationsSingleTarget
IF OBJECT_ID('tempdb..#SPCCalculationsDayDifference')                           IS NOT NULL DROP TABLE #SPCCalculationsDayDifference
IF OBJECT_ID('tempdb..#SPCCalculationsDayDifferenceTransformed')                IS NOT NULL DROP TABLE #SPCCalculationsDayDifferenceTransformed
IF OBJECT_ID('tempdb..#SPCCalculationsDayDifferenceTransformedMean')            IS NOT NULL DROP TABLE #SPCCalculationsDayDifferenceTransformedMean
IF OBJECT_ID('tempdb..#SPCCalculationsMean')                                    IS NOT NULL DROP TABLE #SPCCalculationsMean
IF OBJECT_ID('tempdb..#SPCCalculationsMovingRange')                             IS NOT NULL DROP TABLE #SPCCalculationsMovingRange
IF OBJECT_ID('tempdb..#SPCCalculationsMovingRangeMean')                         IS NOT NULL DROP TABLE #SPCCalculationsMovingRangeMean
IF OBJECT_ID('tempdb..#SPCCalculationsDayDifferenceTransformedMovingRangeMean') IS NOT NULL DROP TABLE #SPCCalculationsDayDifferenceTransformedMovingRangeMean
IF OBJECT_ID('tempdb..#SPCCalculationsMovingRangeProcessLimit')                 IS NOT NULL DROP TABLE #SPCCalculationsMovingRangeProcessLimit
IF OBJECT_ID('tempdb..#SPCCalculationsProcessLimits')                           IS NOT NULL DROP TABLE #SPCCalculationsProcessLimits
IF OBJECT_ID('tempdb..#SPCCalculationsBaselineLimits')                          IS NOT NULL DROP TABLE #SPCCalculationsBaselineLimits
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseSinglePoint')                 IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseSinglePoint
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseShiftPrep')                   IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseShiftPrep
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseShiftPartitionCount')         IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseShiftPartitionCount
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseShiftStartFlag')              IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseShiftStartFlag
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseShiftStartFlagCount')         IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseShiftStartFlagCount
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseShift')                       IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseShift
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTrendPrep')                   IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTrendPrep
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTrendPartitionCount')         IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTrendPartitionCount
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTrendStartFlag')              IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTrendStartFlag
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTrendStartFlagCount')         IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTrendStartFlagCount
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTrend')                       IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTrend
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTwoThreeSigmaPrep')           IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTwoThreeSigmaPrep
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTwoThreeSigmaStartFlag')      IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTwoThreeSigmaStartFlag
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTwoThreeSigmaStartFlagCount') IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTwoThreeSigmaStartFlagCount
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseTwoThreeSigma')               IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseTwoThreeSigma
IF OBJECT_ID('tempdb..#SPCCalculationsSpecialCauseCombined')                    IS NOT NULL DROP TABLE #SPCCalculationsSpecialCauseCombined
IF OBJECT_ID('tempdb..#SPCCalculationsIcons')                                   IS NOT NULL DROP TABLE #SPCCalculationsIcons
IF OBJECT_ID('tempdb..#SPCCalculationsRowCount')                                IS NOT NULL DROP TABLE #SPCCalculationsRowCount
IF OBJECT_ID('tempdb..#Warnings')                                               IS NOT NULL DROP TABLE #Warnings

-- Print message for end of step
SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 7  complete, clear-up'
RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- COLUMN INDEX
--====================================================================================================================================================================================================--
--
-- COLUMN NAME                                                DATA TYPE      RETURNED      CREATION STEP(S)     VALUE
-- [Annotation]                                               Text           6: Output     3b / 4b              User-defined or NULL (optional) turned blank
-- [AssuranceIcon]                                            Text           6: Output     4k / 6               Calculated from [LowerProcessLimit], [MetricImprovement], [Target] and [UpperProcessLimit]: NULL if [ChartType] not 'XmR' or [MetricImprovement] not 'Down' or 'Up' or [PointExcludeGhostingRankDescending] not 1 or [Target] = NULL or [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [BaselineEndFlag]                                          Number         No            4c                   Calculated from 3c: 1 or 0
-- [BaselineFlag]                                             Number         No            4c                   Calculated from [BaselineEndFlag]: 1 or 0
-- [BaselineEndRank]                                          Number         No            4c                   Calculated from 3c: NULL if [BaselineEndFlag] = 0
-- [BaselineOrder]                                            Number         No            3c                   User-defined (optional); distinct number; can be added automatically
-- [ChartID]                                                  Text           6: Output     3b                   Concatenation of [MetricID], [GroupHierarchy], [Group], [Filter1], and [Filter2]
-- [ChartTitle]                                               Text           6: Output     3a / 4b              User-defined or NULL (optional) turned blank
-- [ChartType]                                                Text           6: Output     3a                   User-defined
-- [Date]                                                     Date           6: Output     3b / 3c              User-defined (or NULL and optional for 3c)
-- [DateFormat]                                               Text           6: Output     3a                   User-defined
-- [DayDifference]                                            Number         No            4e                   Calculated from [Date]; NULL if [ChartType] not 'T'
-- [DayDifferenceTransformed]                                 Number         No            4e                   Calculated from [DayDifference]
-- [DayDifferenceTransformedMean]                             Number         No            4e                   Calculated from [DayDifferenceTransformed]
-- [DayDifferenceTransformedMovingRange]                      Number         No            4e                   Calculated from [DayDifferenceTransformed]; NULL if [GhostFlag] = 1
-- [DayDifferenceTransformedMovingRangeMean]                  Number         No            4e                   Calculated from [DayDifferenceTransformedMovingRange]
-- [Detail]                                                   Text           5: Warning    5                    Various
-- [EndDate]                                                  Date           No            3d                   User-defined or NULL (optional)
-- [Filter1]                                                  Text           6: Output     3b / 4b              User-defined or NULL (optional)
-- [Filter2]                                                  Text           6: Output     3b / 4b              User-defined or NULL (optional)
-- [GhostFlag]                                                Number         No            3b                   User-defined: 1 or 0
-- [GhostValue]                                               Number         6: Output     3b                   Calculated from [GhostFlag] and [Value]
-- [Group]                                                    Text           No            3b / 3c / 3d         User-defined (or NULL and optional for 3c / 3d)
-- [GroupHierarchy]                                           Number         6: Output     4a                   Calculated from [Group], GroupHierarchyOrder, and [GroupParent] hierarchy (3b)
-- [GroupHierarchyOrder]                                      Number         No            4a                   User-defined or NULL (optional)
-- [GroupLevel]                                               Text           No            4a                   Calculated from [Group], GroupHierarchyOrder, and [GroupParent] hierarchy (3b)
-- [GroupName]                                                Text           6: Output     4b                   Concatenation of [GroupHierarchy], @SettingGroupHierarchyIndentSpaces (2b), and [Group]
-- [GroupOrder]                                               Number         6: Output     4a                   ROW_NUMBER from [GroupLevel]
-- [GroupParent]                                              Text           No            3b                   User-defined or NULL
-- [HorizontalAxisTitle]                                      Text           6: Output     3a / 4b              User-defined or NULL (optional) turned blank
-- [IconID]                                                   Text           6: Output     4k                   Concatenation of [MetricID], [GroupHierarchy], [Group], [Filter1], and [Filter2]; NULL if [PointExcludeGhostingRankDescending] not 1
-- [LowerBaseline]                                            Number         6: Output     4e / 6               Calculated from [LowerProcessLimit]; NULL if [BaselineFlag] = 0 or [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [LowerOneSigma]                                            Number         6: Output     4e / 6               Calculated from [DayDifferenceTransformedMean], [DayDifferenceTransformedMovingRangeMean], [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [LowerProcessLimit]                                        Number         6: Output     4e / 6               Calculated from [DayDifferenceTransformedMean], [DayDifferenceTransformedMovingRangeMean], [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [LowerTwoSigma]                                            Number         6: Output     4e / 6               Calculated from [DayDifferenceTransformedMean], [DayDifferenceTransformedMovingRangeMean], [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [LowMeanWarningValue]                                      Number         No            3a                   User-defined or NULL
-- [Mean]                                                     Number         6: Output     4e                   Calculated from [DayDifferenceTransformedMean], [MeanWithoutOutliers], and [Value]; NULL if [GhostFlag] = 1
-- [MeanWithoutOutliers]                                      Number         6: Output     4e                   Calculated from [Value]; NULL if [GhostFlag] = 1
-- [MetricConflictRule]                                       Text           No            3a                   User-defined or NULL
-- [MetricFormat]                                             Text           6: Output     3a                   User-defined
-- [MetricID]                                                 Text           6: Output     3a / 3b / 3c  3d     User-defined (optional for 3c / 3d)
-- [MetricImprovement]                                        Text           No            3a                   User-defined
-- [MetricName]                                               Text           6: Output     3a                   User-defined
-- [MetricOrder]                                              Number         6: Output     3a                   User-defined; distinct number; can be added automatically
-- [MovingRange]                                              Number         6: Output     4e                   Calculated from [Value]; NULL if [ChartType] not 'XmR' or [GhostFlag] = 1
-- [MovingRangeHighPointValue]                                Number         6: Output     4e / 6               Calculated from [MovingRangeMean], [MovingRange]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [MovingRangeMean]                                          Number         6: Output     4e                   Calculated from [MovingRangeWithPartition] and [PartitionMovingRangeMean]
-- [MovingRangeMeanForProcessLimits]                          Number         No            4e                   Calculated from [MovingRangeMean], [PartitionMovingRangeMeanForProcessLimits], and [MovingRangeMeanWithoutOutliers]
-- [MovingRangeMeanWithoutOutliers]                           Number         No            4e                   Calculated from [MovingRangeWithPartition]
-- [MovingRangeProcessLimit]                                  Number         6: Output     4e / 6               Calculated from [MovingRangeMean]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [MovingRangeWithPartition]                                 Number         No            4e                   Calculated from [Value]; ; NULL if [ChartType] not 'XmR' or [GhostFlag] = 1
-- [PartitionDayDifferenceTransformedMean]                    Number         No            4e                   Calculated from [DayDifferenceTransformedMean]
-- [PartitionDayDifferenceTransformedMovingRangeMean]         Number         No            4e                   Calculated from [DayDifferenceTransformedMovingRangeMean]
-- [PartitionID]                                              Number         No            4b / 4c              Calculated from [RecalculateLimitsFlag]
-- [PartitionIDExcludeGhosting]                               Number         No            4b / 4c              Calculated from [RecalculateLimitsFlag]; NULL if [GhostFlag] = 1
-- [PartitionMean]                                            Number         No            4e                   Calculated from [Mean]
-- [PartitionMovingRangeMean]                                 Number         No            4e                   Calculated from [MovingRangeMean]
-- [PartitionMovingRangeMeanForProcessLimits]                 Number         No            4e                   Calculated from [MovingRangeMean]
-- [PointsExcludeGhosting]                                    Number         No            3c                   User-defined or NULL (optional)
-- [PointExcludeGhostingRankAscending]                        Number         No            4b                   ROW_NUMBER; NULL if [GhostFlag] = 1
-- [PointExcludeGhostingRankDescending]                       Number         No            4b                   ROW_NUMBER; NULL if [GhostFlag] = 1
-- [PointRank]                                                Text           6: Output     4b                   ROW_NUMBER
-- [RecalculateLimitsFlag]                                    Number         No            3b                   User-defined: 1 or 0
-- [RowCountExcludeGhosting]                                  Number         No            4l                   Calculated from [GhostFlag] and [PointRank]
-- [RowID]                                                    Text           6: Output     4b                   Concatenation of [MetricID], [GroupHierarchy], [Group], [Filter1], [Filter2], and ascending order of [Date]
-- [SpecialCauseAboveMeanFlag]                                Number         No            4g                   Calculated from [Mean] and [Value]; 0 if [GhostFlag] = 1
-- [SpecialCauseAboveMeanPartitionCount]                      Number         No            4g                   Calculated from [SpecialCauseAboveMeanFlag]
-- [SpecialCauseBelowMeanFlag]                                Number         No            4g                   Calculated from [Mean] and [Value]; 0 if [GhostFlag] = 1
-- [SpecialCauseBelowMeanPartitionCount]                      Number         No            4g                   Calculated from [SpecialCauseBelowMeanFlag]
-- [SpecialCauseConcernValue]                                 Number         6: Output     4j / 6               Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], [SpecialCauseRuleTrendIncreasingFlag], [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag], [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag], and [Value]: NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [SpecialCauseConflictFlag]                                 Number         No            4j                   Calculated from [MetricConflictRule], [SpecialCauseConcernValue], and [SpecialCauseImprovementValue]: 1 or 0
-- [SpecialCauseDecreasingFlag]                               Number         No            4h                   Calculated from [Value]: 1 or 0; 0 if [GhostFlag] = 1
-- [SpecialCauseDecreasingPartitionCount]                     Number         No            4h                   Calculated from [SpecialCauseDecreasingFlag]
-- [SpecialCauseImprovementValue]                             Number         6: Output     4j / 6               Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], [SpecialCauseRuleTrendIncreasingFlag], [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag], [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag], and [Value]: NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [SpecialCauseIncreasingFlag]                               Number         No            4h                   Calculated from [Value]: 1 or 0; 0 if [GhostFlag] = 1
-- [SpecialCauseIncreasingPartitionCount]                     Number         No            4h                   Calculated from [SpecialCauseIncreasingFlag]
-- [SpecialCauseNeitherHighFlag]                              Number         No            4j                   Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleTrendIncreasingFlag], and [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]: 1 or 0
-- [SpecialCauseNeitherLowFlag]                               Number         No            4j                   Calculated from [MetricImprovement], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], and [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]: 1 or 0
-- [SpecialCauseNeitherValue]                                 Number         6: Output     4j / 6               Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], [SpecialCauseRuleTrendIncreasingFlag], [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag], [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag], and [Value]: NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [SpecialCauseRuleShiftAboveMeanFlag]                       Number         No            4g                   Calculated from [SpecialCauseShiftAboveMeanStartFlagCount] and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseRuleShiftBelowMeanFlag]                       Number         No            4g                   Calculated from [SpecialCauseShiftBelowMeanStartFlagCount] and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    Number         No            4f                   Calculated from [LowerProcessLimit] and [Value]: 1 or 0; 0 if [GhostFlag] = 1
-- [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    Number         No            4f                   Calculated from [UpperProcessLimit] and [Value]: 1 or 0; 0 if [GhostFlag] = 1
-- [SpecialCauseRuleTrendDecreasingFlag]                      Number         No            4h                   Calculated from [SpecialCauseTrendDecreasingStartFlagCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseRuleTrendIncreasingFlag]                      Number         No            4h                   Calculated from [SpecialCauseTrendIncreasingStartFlagCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]               Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaAboveMeanFlag] and [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount]: 1 or 0
-- [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]               Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaBelowMeanFlag] and [SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount]: 1 or 0
-- [SpecialCauseShiftAboveMeanStartFlag]                      Number         No            4g                   Calculated from [SpecialCauseAboveMeanFlag], [SpecialCauseAboveMeanPartitionCount], and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseShiftAboveMeanStartFlagCount]                 Number         No            4g                   Calculated from [SpecialCauseShiftAboveMeanStartFlag]
-- [SpecialCauseShiftBelowMeanStartFlag]                      Number         No            4g                   Calculated from [SpecialCauseBelowMeanFlag], [SpecialCauseBelowMeanPartitionCount], and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseShiftBelowMeanStartFlagCount]                 Number         No            4g                   Calculated from [SpecialCauseShiftBelowMeanStartFlag]
-- [SpecialCauseTrendDecreasingStartFlag]                     Number         No            4h                   Calculated from [SpecialCauseDecreasingPartitionCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseTrendDecreasingStartFlagCount]                Number         No            4h                   Calculated from [SpecialCauseTrendDecreasingStartFlag] 
-- [SpecialCauseTrendIncreasingStartFlag]                     Number         No            4h                   Calculated from [SpecialCauseIncreasingPartitionCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseTrendIncreasingStartFlagCount]                Number         No            4h                   Calculated from [SpecialCauseTrendIncreasingStartFlag] 
-- [SpecialCauseTwoThreeSigmaAboveMeanFlag]                   Number         No            4i                   Calculated from [UpperProcessLimit], [UpperTwoSigma] and [Value]: 1 or 0: 0 if [GhostFlag] = 1
-- [SpecialCauseTwoThreeSigmaAboveMeanStartFlag]              Number         No            4i                   Calculated from [SpecialCauseAboveMeanFlag] and [SpecialCauseTwoThreeSigmaAboveMeanFlag]: 1 or 0
-- [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount]         Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaAboveMeanStartFlag]
-- [SpecialCauseTwoThreeSigmaBelowMeanFlag]                   Number         No            4i                   Calculated from [LowerProcessLimit], [LowerTwoSigma] and [Value]: 1 or 0: 0 if [GhostFlag] = 1
-- [SpecialCauseTwoThreeSigmaBelowMeanStartFlag]              Number         No            4i                   Calculated from [SpecialCauseBelowMeanFlag] and [SpecialCauseTwoThreeSigmaBelowMeanFlag]: 1 or 0
-- [SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount]         Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaBelowMeanStartFlag]
-- [StartDate]                                                Date           No            3d                   User-defined or NULL (optional)
-- [Target]                                                   Number         6: Output     3d                   User-defined (optional)
-- [TargetOrder]                                              Number         No            3d                   User-defined (optional); distinct number; can be added automatically
-- [TargetRank]                                               Number         No            4d                   Calculated from 3d
-- [UpperBaseline]                                            Number         6: Output     4e / 6               Calculated from [UpperProcessLimit]; NULL if [BaselineFlag] = 0 or [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [UpperOneSigma]                                            Number         6: Output     4e / 6               Calculated from [DayDifferenceTransformedMean], [DayDifferenceTransformedMovingRangeMean], [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [UpperProcessLimit]                                        Number         6: Output     4e / 6               Calculated from [DayDifferenceTransformedMean], [DayDifferenceTransformedMovingRangeMean], [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [UpperTwoSigma]                                            Number         6: Output     4e / 6               Calculated from [DayDifferenceTransformedMean], [DayDifferenceTransformedMovingRangeMean], [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [Value]                                                    Number         6: Output     3b                   User-defined or NULL
-- [VariationIcon]                                            Text           6: Output     4k / 6               Calculated from [MetricImprovement], [SpecialCauseConcernValue], [SpecialCauseImprovementValue], [SpecialCauseNeitherHighFlag] and [SpecialCauseNeitherLowFlag]; NULL if [MetricImprovement] not 'Up', 'Down', or 'Neither' or [PointExcludeGhostingRankDescending] not 1 or [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [VerticalAxisMaxFix]                                       Number         6: Output     3a                   User-defined or NULL
-- [VerticalAxisMaxFlex]                                      Number         6: Output     3a                   User-defined or NULL
-- [VerticalAxisMinFix]                                       Number         6: Output     3a                   User-defined or NULL
-- [VerticalAxisMinFlex]                                      Number         6: Output     3a                   User-defined or NULL
-- [VerticalAxisTitle]                                        Text           6: Output     3a / 4b              User-defined or NULL (optional) turned blank
-- [Warning]                                                  Text           5: Warning    5                    Various
--
--====================================================================================================================================================================================================--