--CR123
--Open Orders
--This query provides a list of open purchase orders and their encumbrance and/or amount paid, broken down by purchase order lines. 
--It does not include any invoice line data not attached to a purchase order line and adjustments made at the invoice level.

/* FIELDS TO INCLUDE:
 Invoice table:
 Invoice ID
 Invoice currency  
 Invocie vendor invoice 
 Invoice Line table:
 Invoice Lines iD
 Invoice Lines status
 Invoice Lines total                 
 Purchase Order Table:
 Purchase order type
 Purchase order number
 Purchase Order Line Table:
 Purchase order line ID
 Purchase order line number
 Purchase order line format
 Purchase order line title or package,
 Purchase order line status
 Purchase order line physical material
 Purchase order line electronic material
 Derived tables folio_reporting:
 	PO organization
 		Vendor name	
 	Invoice_lines_fund distribution
 		Invoice Line total 
 	Instance_ext
 		Instance ID
 		Instance format
 	PO instance
 		Instance HRID
 	Instance format
 		ID
 		format name
 	Finance transaction invoices
 		Transaction amount
 		Transaction currency
 	Finance transactions purchase order
 		Transaction encumbrance initial amount
 */
/* Change the lines below to filter or leave blank to return all results. Add details in '' for a specific filter.*/
WITH parameters AS (
    SELECT
        ''::varchar AS order_type, -- select 'One-Time' or 'Ongoing' or leave blank for both
        ''::varchar AS order_format, -- select 'Electronic Resource', 'Physical Resource', 'P/E Mix', 'Other' or leave blank for all
        ''::varchar AS instance_format_name, -- example: select e-resources vs physical (eg. "computer-online resource" for electronic resources or "Phycical Resource" for phycial resources)
        ''::varchar AS instance_mode_of_issuance, -- example: 'single unit', 'serial' etc. Mostly used by DBS
        ''::varchar AS transaction_type -- example:'Payment', 'Pending payment'
),
 funds_distr AS (
    SELECT
        id AS po_line_id,
        json_extract_path_text(dist.data, 'code') AS fund_distribution_code,
        json_extract_path_text(dist.DATA,'encumbrance AS fund_encumbrance'),
        json_extract_path_text(dist.data, 'fundId') AS fund_distribution_id,
        json_extract_path_text(dist.data, 'expenseClassId') AS fund_expense_class_id,
        json_extract_path_text(dist.data, 'distributionType') AS fund_distribution_type,
        json_extract_path_text(dist.data, 'value')::numeric AS fund_distribution_value
    FROM
        po_lines AS pol
        CROSS JOIN json_array_elements(json_extract_path(data, 'fundDistribution')) WITH ORDINALITY AS dist(data)
)
    ---MAIN QUERY
SELECT
   CURRENT_DATE,
   ilfd.finance_fund_code,
   ppo.po_number AS po_number,
   poi.created_date::date AS po_created_date,
   pol.po_line_number,
   poorg.org_name AS vendor_name,
   pol.title_or_package AS pol_title_or_package,
   poi.title AS instance_title,
   poi.pol_instance_hrid AS instance_hrid,
   ppo.order_type AS po_order_type,
   pol.order_format AS pol_order_format,
   ifo.format_name AS instance_format_name,
   pol.payment_status,
   pol.receipt_status AS pol_receipt_status,
   pol_phys_type.pol_mat_type_name AS pol_phys_mat_type_name,
   pol_er_type.pol_er_mat_type_name AS pol_er_mat_type_name,
   invl.id AS invl_id,
   invl.invoice_line_status AS invl_status,
   inv.payment_date,
   inv.vendor_invoice_no,
   frftp.transaction_encumbrance_initial_amount::NUMERIC(12,2),
   fti.transaction_amount,
   fti.transaction_currency,
   fti.transaction_type
FROM
	po_lines AS pol
	LEFT JOIN po_purchase_orders AS ppo ON ppo.id = pol.purchase_order_id
	LEFT JOIN invoice_lines AS invl ON pol.id = invl.po_line_id
	LEFT JOIN invoice_invoices AS inv ON invl.invoice_id = inv.id
	LEFT JOIN folio_reporting.po_organization poorg ON ppo.po_number = poorg.po_number
	LEFT JOIN folio_reporting.invoice_lines_fund_distributions AS ilfd ON ilfd.invoice_line_id = invl.id 
	LEFT JOIN folio_reporting.instance_ext AS iext ON iext.instance_id = pol.instance_id
	LEFT JOIN folio_reporting.instance_formats AS ifo ON ifo.instance_id = iext.instance_id
	LEFT JOIN folio_reporting.po_lines_phys_mat_type AS pol_phys_type ON pol.id = pol_phys_type.pol_id
	LEFT JOIN folio_reporting.po_lines_er_mat_type AS pol_er_type ON pol.id = pol_er_type.pol_id
	LEFT JOIN folio_reporting.po_instance AS poi ON poi.po_line_number = pol.po_line_number
	LEFT JOIN folio_reporting.finance_transaction_invoices AS fti ON fti.invoice_line_id=invl.id AND ilfd.finance_fund_code=fti.transaction_from_fund_code
	LEFT JOIN folio_reporting.finance_transaction_purchase_order AS frftp ON frftp.pol_number = pol.po_line_number
WHERE  
	ppo.workflow_status LIKE 'Open'
    AND (ppo.order_type = (SELECT order_type FROM parameters) OR (SELECT order_type FROM parameters) = '')
    AND (pol.order_format = (SELECT order_format FROM parameters) OR (SELECT order_format FROM parameters) = '')
    AND (ifo.format_name = (SELECT instance_format_name FROM parameters) OR (SELECT instance_format_name FROM parameters) = '')
    AND (iext.mode_of_issuance_name = (SELECT instance_mode_of_issuance FROM parameters) OR (SELECT instance_mode_of_issuance FROM parameters) = '')
    AND (fti.transaction_type = (SELECT transaction_type FROM parameters) OR (SELECT transaction_type FROM parameters) = '')
GROUP BY
	ppo.order_type,
   	ilfd.finance_fund_code,
   	pol.po_line_number,
	pol.title_or_package,
	poi.title,
    pol.order_format,
    pol.receipt_status,
    ifo.format_name,
    invl.id,
    invl.invoice_line_status,
    invl.total,
    ppo.po_number,
    ppo.workflow_status,
    poorg.org_name,
    pol.payment_status,
    pol_phys_type.pol_mat_type_name,
    pol_er_type.pol_er_mat_type_name,
    poi.pol_instance_hrid,
   	ilfd.invoice_line_total,
    inv.currency,
    inv.vendor_invoice_no,
	fti.transaction_amount,
	fti.transaction_currency,
	fti.transaction_type,
	frftp.transaction_encumbrance_initial_amount,
	inv.payment_date,
	poi.created_date
ORDER BY 
	finance_fund_code ASC;
	