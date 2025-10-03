SELECT 
    m.away_team,
    COUNT(CASE WHEN m.home_win = 'Loss' THEN 1 END) AS away_wins,   -- away wins when home lost
    COUNT(CASE WHEN m.home_win = 'Draw' THEN 1 END) AS away_draws,
    COUNT(CASE WHEN m.home_win = 'Win' THEN 1 END) AS away_losses,
    COUNT(*) AS total_matches,
    ROUND(AVG(m.away_xg), 2) AS avg_xg,
    ROUND(AVG(m.away_shots), 2) AS avg_shots,
    ROUND(AVG(m.away_goals), 2) AS avg_goals,
    ROUND(AVG(m.away_possession), 2) AS avg_possession,
    ROUND(AVG(m.away_pass_accuracy), 2) AS avg_pass_accuracy,
    ROUND(SUM(m.away_goals) * 1.0 / NULLIF(SUM(m.away_xg),0), 2) AS goal_rate,
    ROUND((
        (AVG(m.away_xg) / (SELECT MAX(avg_away_xg) FROM (SELECT AVG(away_xg) AS avg_away_xg FROM matches GROUP BY away_team) t)) +
        (AVG(m.away_shots) / (SELECT MAX(avg_away_shots) FROM (SELECT AVG(away_shots) AS avg_away_shots FROM matches GROUP BY away_team) t)) +
        (AVG(m.away_goals) / (SELECT MAX(avg_away_goals) FROM (SELECT AVG(away_goals) AS avg_away_goals FROM matches GROUP BY away_team) t)) +
        (AVG(m.away_possession) / 100.0) +
        (AVG(m.away_pass_accuracy) / 100.0) +
        ((SUM(m.away_goals) * 1.0 / NULLIF(SUM(m.away_xg),0)) / 
            (SELECT MAX(goal_rate) FROM (
                SELECT SUM(away_goals) * 1.0 / NULLIF(SUM(away_xg),0) AS goal_rate 
                FROM matches GROUP BY away_team
            ) t))
    ) / 6 * 100, 2) AS top_form_percentage
FROM matches m
GROUP BY m.away_team
ORDER BY top_form_percentage DESC;
