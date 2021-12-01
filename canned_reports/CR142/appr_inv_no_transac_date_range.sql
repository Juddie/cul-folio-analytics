--This query provides the list of approved invoices within a date range for which transactions has not been created.
--This query should not return any data if the system is working properly.

WITH parameters AS (
    SELECT
        /* enter invoice payment start date and end date in YYYY-MM-DD format */
    	'2021-08-01' :: DATE AS payment_date_start_date,
        '2022-06-30' :: DATE AS payment_date_end_date -- Excludes the selected date
)
SELECT 
	current_date AS current_date,		
		(SELECT
			payment_date_start_date::varchar
     	FROM
        	parameters) || ' to '::varchar || (
     	SELECT
        	payment_date_end_date::varchar
     	FROM
        	parameters) AS payment_date_range,
    inv.payment_date::date,
    oo.name AS vendor_name,
	inv.vendor_invoice_no AS invoice_no,
	SUM (CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >1 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END) AS transaction_amount -- This line transfrom transaction type 'credits' into a negatie amount
FROM
	invoice_invoices AS inv 
	LEFT JOIN folio_reporting.finance_transaction_invoices AS fti ON fti.invoice_id = inv.id
	LEFT JOIN invoice_lines AS invl ON invl.id = fti.invoice_line_id 
	LEFT JOIN organization_organizations AS oo ON json_extract_path_text(inv.data, 'vendorId') = oo.id
WHERE
	(inv.payment_date::date >= (SELECT payment_date_start_date FROM parameters)) 
	AND (inv.payment_date::date < (SELECT payment_date_end_date FROM parameters))
	AND inv.status LIKE 'Paid'
	AND fti.transaction_id ISNULL
GROUP BY 
	oo.name,
	inv.vendor_invoice_no,
	inv.payment_date	
ORDER BY 
	inv.payment_date ASC,
	oo.name,
	inv.vendor_invoice_no
	;
