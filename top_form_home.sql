SELECT 
    m.home_team,
    COUNT(CASE WHEN m.home_win = 'Win' THEN 1 END) AS home_wins,
    COUNT(CASE WHEN m.home_win = 'Draw' THEN 1 END) AS home_draws,
    COUNT(CASE WHEN m.home_win = 'Loss' THEN 1 END) AS home_losses,
    COUNT(*) AS total_matches,
    ROUND(AVG(m.home_xg), 2) AS avg_xg,
    ROUND(AVG(m.home_shots), 2) AS avg_shots,
    ROUND(AVG(m.home_goals), 2) AS avg_goals,
    ROUND(AVG(m.home_possession), 2) AS avg_possession,
    ROUND(AVG(m.home_pass_accuracy), 2) AS avg_pass_accuracy,
    ROUND(SUM(m.home_goals) * 1.0 / NULLIF(SUM(m.home_xg),0), 2) AS goal_rate,
    ROUND((
        (AVG(m.home_xg) / (SELECT MAX(avg_home_xg) FROM (SELECT AVG(home_xg) AS avg_home_xg FROM matches GROUP BY home_team) t)) +
        (AVG(m.home_shots) / (SELECT MAX(avg_home_shots) FROM (SELECT AVG(home_shots) AS avg_home_shots FROM matches GROUP BY home_team) t)) +
        (AVG(m.home_goals) / (SELECT MAX(avg_home_goals) FROM (SELECT AVG(home_goals) AS avg_home_goals FROM matches GROUP BY home_team) t)) +
        (AVG(m.home_possession) / 100.0) +
        (AVG(m.home_pass_accuracy) / 100.0) +
        ((SUM(m.home_goals) * 1.0 / NULLIF(SUM(m.home_xg),0)) / 
            (SELECT MAX(goal_rate) FROM (
                SELECT SUM(home_goals) * 1.0 / NULLIF(SUM(home_xg),0) AS goal_rate 
                FROM matches GROUP BY home_team
            ) t))
    ) / 6 * 100, 2) AS top_form_percentage
FROM matches m
GROUP BY m.home_team
ORDER BY top_form_percentage DESC;
