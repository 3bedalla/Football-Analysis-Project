SELECT 
    team,
    SUM(wins) AS total_wins,
    SUM(draws) AS total_draws,
    SUM(losses) AS total_losses,
    COUNT(*) AS total_matches,
    ROUND(AVG(xg), 2) AS avg_xg,
    ROUND(AVG(shots), 2) AS avg_shots,
    ROUND(AVG(goals), 2) AS avg_goals,
    ROUND(AVG(possession), 2) AS avg_possession,
    ROUND(AVG(pass_accuracy), 2) AS avg_pass_accuracy,
    ROUND(SUM(goals) * 1.0 / NULLIF(SUM(xg),0), 2) AS goal_rate,
    ROUND((
        (AVG(xg) / (SELECT MAX(avg_xg) FROM (SELECT team, AVG(xg) AS avg_xg FROM (
            SELECT home_team AS team, home_xg AS xg FROM matches
            UNION ALL
            SELECT away_team, away_xg FROM matches
        ) t1 GROUP BY team) t2)) +
        (AVG(shots) / (SELECT MAX(avg_shots) FROM (SELECT team, AVG(shots) AS avg_shots FROM (
            SELECT home_team AS team, home_shots AS shots FROM matches
            UNION ALL
            SELECT away_team, away_shots FROM matches
        ) t1 GROUP BY team) t2)) +
        (AVG(goals) / (SELECT MAX(avg_goals) FROM (SELECT team, AVG(goals) AS avg_goals FROM (
            SELECT home_team AS team, home_goals AS goals FROM matches
            UNION ALL
            SELECT away_team, away_goals FROM matches
        ) t1 GROUP BY team) t2)) +
        (AVG(possession) / 100.0) +
        (AVG(pass_accuracy) / 100.0) +
        ((SUM(goals) * 1.0 / NULLIF(SUM(xg),0)) /
            (SELECT MAX(goal_rate) FROM (
                SELECT team, SUM(goals) * 1.0 / NULLIF(SUM(xg),0) AS goal_rate
                FROM (
                    SELECT home_team AS team, home_goals AS goals, home_xg AS xg FROM matches
                    UNION ALL
                    SELECT away_team, away_goals, away_xg FROM matches
                ) t1
                GROUP BY team
            ) t2))
    ) / 6 * 100, 2) AS top_form_percentage
FROM (
    -- Home side
    SELECT 
        home_team AS team,
        CASE WHEN home_win = 'Win' THEN 1 ELSE 0 END AS wins,
        CASE WHEN home_win = 'Draw' THEN 1 ELSE 0 END AS draws,
        CASE WHEN home_win = 'Loss' THEN 1 ELSE 0 END AS losses,
        home_xg AS xg,
        home_shots AS shots,
        home_goals AS goals,
        home_possession AS possession,
        home_pass_accuracy AS pass_accuracy
    FROM matches
    UNION ALL
    -- Away side
    SELECT 
        away_team AS team,
        CASE WHEN home_win = 'Loss' THEN 1 ELSE 0 END AS wins,
        CASE WHEN home_win = 'Draw' THEN 1 ELSE 0 END AS draws,
        CASE WHEN home_win = 'Win' THEN 1 ELSE 0 END AS losses,
        away_xg AS xg,
        away_shots AS shots,
        away_goals AS goals,
        away_possession AS possession,
        away_pass_accuracy AS pass_accuracy
    FROM matches
) combined
GROUP BY team
ORDER BY top_form_percentage DESC;
