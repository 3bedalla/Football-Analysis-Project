WITH all_matches AS (
    SELECT 
        CASE WHEN date IS NOT NULL 
            THEN CAST(strftime('%Y', date) AS INTEGER)   -- SQLite example; adjust for your DB
            ELSE season END AS season,
        home_team, away_team,
        home_xg, away_xg,
        home_shots, away_shots,
        home_goals, away_goals,
        home_possession, away_possession,
        home_pass_accuracy, away_pass_accuracy,
        home_win
    FROM matches
),

-- unify rows so team appears once per match as either home or away
team_match_rows AS (
    SELECT
        season,
        home_team AS team,
        CASE WHEN home_win = 'Win' THEN 1 ELSE 0 END AS is_win,
        CASE WHEN home_win = 'Draw' THEN 1 ELSE 0 END AS is_draw,
        CASE WHEN home_win = 'Loss' THEN 1 ELSE 0 END AS is_loss,
        home_xg AS xg,
        home_shots AS shots,
        home_goals AS goals,
        home_possession AS possession,
        home_pass_accuracy AS pass_accuracy
    FROM all_matches

    UNION ALL

    SELECT
        season,
        away_team AS team,
        CASE WHEN home_win = 'Loss' THEN 1 ELSE 0 END AS is_win,
        CASE WHEN home_win = 'Draw' THEN 1 ELSE 0 END AS is_draw,
        CASE WHEN home_win = 'Win' THEN 1 ELSE 0 END AS is_loss,
        away_xg AS xg,
        away_shots AS shots,
        away_goals AS goals,
        away_possession AS possession,
        away_pass_accuracy AS pass_accuracy
    FROM all_matches
),

-- compute per-team-season aggregates and the goal_rate
team_season_agg AS (
    SELECT
        season,
        team,
        SUM(is_win) AS wins,
        SUM(is_draw) AS draws,
        SUM(is_loss) AS losses,
        COUNT(*) AS matches_played,
        AVG(xg) AS avg_xg,
        AVG(shots) AS avg_shots,
        AVG(goals) AS avg_goals,
        AVG(possession) AS avg_possession,
        AVG(pass_accuracy) AS avg_pass_accuracy,
        SUM(goals) * 1.0 / NULLIF(SUM(xg),0) AS goal_rate,
        SUM(goals) AS total_goals,
        SUM(xg) AS total_xg
    FROM team_match_rows
    GROUP BY season, team
),

-- get max per metric (for normalization)
metric_max AS (
    SELECT
        MAX(avg_xg) AS max_avg_xg,
        MAX(avg_shots) AS max_avg_shots,
        MAX(avg_goals) AS max_avg_goals,
        MAX(avg_possession) AS max_avg_possession,
        MAX(avg_pass_accuracy) AS max_avg_pass_accuracy,
        MAX(CASE WHEN goal_rate IS NOT NULL THEN goal_rate ELSE 0 END) AS max_goal_rate
    FROM team_season_agg
)

-- final per-team-season table with normalized top_form_percentage
SELECT
    a.season,
    a.team,
    a.wins,
    a.draws,
    a.losses,
    a.matches_played,
    ROUND(a.avg_xg, 3) AS avg_xg,
    ROUND(a.avg_shots, 3) AS avg_shots,
    ROUND(a.avg_goals, 3) AS avg_goals,
    ROUND(a.avg_possession, 2) AS avg_possession,
    ROUND(a.avg_pass_accuracy, 2) AS avg_pass_accuracy,
    ROUND(a.goal_rate, 3) AS goal_rate,
    -- top_form as %: average of normalized metrics
    ROUND(( 
        (a.avg_xg / NULLIF(m.max_avg_xg,0)) +
        (a.avg_shots / NULLIF(m.max_avg_shots,0)) +
        (a.avg_goals / NULLIF(m.max_avg_goals,0)) +
        (a.avg_possession / NULLIF(m.max_avg_possession,0)) +  -- already 0-100
        (a.avg_pass_accuracy / NULLIF(m.max_avg_pass_accuracy,0)) + -- already 0-100
        (a.goal_rate / NULLIF(m.max_goal_rate,0))
    ) / 6 * 100, 2) AS top_form_pct,
    (3 * a.wins + 1 * a.draws) AS points  -- classic points (useful target)
FROM team_season_agg a CROSS JOIN metric_max m
ORDER BY season, points DESC;
