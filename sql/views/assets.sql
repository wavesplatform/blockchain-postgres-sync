create view assets as (
  select 
    issue.asset_id,
    t.ticker,
    issue.asset_name,
    issue.description,
    issue.sender,
    issue.height as issue_height,
    issue.time_stamp as issue_timestamp,
    issue.quantity::numeric
      + coalesce(reissue_q.reissued_total, 0)::numeric
      - coalesce(burn_q.burned_total, 0):: numeric as total_quantity,
    issue.decimals,
    coalesce(reissuable_last.reissuable, issue.reissuable) as reissuable
  from txs_3 issue
  -- total reissue quantity
  left join (
    select
      asset_id,
      sum(quantity) as reissued_total
    from txs_5
    group by asset_id
  ) reissue_q on (issue.asset_id = reissue_q.asset_id)
  -- total burn quantity
  left join (
    select
      asset_id,
      sum(amount) as burned_total
    from txs_6
    group by asset_id
  ) burn_q on (issue.asset_id = burn_q.asset_id)
  -- last reissuable value
  left join (
    select distinct on (asset_id)
      asset_id,
      time_stamp,
      reissuable
    from txs_5
    order by asset_id, time_stamp desc
  ) reissuable_last on (issue.asset_id = reissuable_last.asset_id)
  -- tickers
  left join (
    select asset_id, ticker
    from tickers
  ) t on (issue.asset_id = t.asset_id)
  union all
  select 'WAVES', 'WAVES', 'Waves', '', '', 0, '2016-04-11 21:00:00', 10000000000000000::numeric, 8, false
);