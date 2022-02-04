# hrm_server
Set of T-SQL procedures for combining HTML Code with Datasets automatically and sending the results as E-Mail messages. Include necessary DDL procedures for data tables creation.. 

Links parameterized HTML code to a specified data source (table, view, or function). 
The matching of parameters to values from the data source is done by matching the parameter name to the source column name.
How the data source records are linked for a given HTML code is done depending on the rest of the settings. 

It is possible to return a separate report for each record from the source or to duplicate the main part of the HTML code for records grouped in the way indicated in the settings. This way, fewer reports are generated than there are records in the source.
