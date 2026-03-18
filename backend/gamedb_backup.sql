--
-- PostgreSQL database dump
--

\restrict lJX8ybW1PziAr9tnMIsmV2uzymvKmFAQg6UISBeuDmADRqVRBgz0XgLPZyWFZkg

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: insert_random_event(uuid, text, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_random_event(p_session_id uuid, p_player_id text, session_start timestamp with time zone, session_end timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    event_types TEXT[] := ARRAY['level_start', 'level_end', 'enemy_killed', 'item_collected', 'player_died', 'checkpoint_reached', 'powerup_used', 'menu_open', 'pause', 'resume'];
    selected_type TEXT;
    event_time TIMESTAMPTZ;
    event_data JSONB;
BEGIN
    -- Случайное время в пределах сессии
    event_time := session_start + (random() * (session_end - session_start));
    
    -- Выбираем тип события
    selected_type := event_types[1 + floor(random() * array_length(event_types, 1))];
    
    -- Формируем JSON в зависимости от типа
    event_data := CASE selected_type
        WHEN 'level_start' THEN jsonb_build_object('level', floor(random()*10)+1, 'difficulty', CASE WHEN random()<0.3 THEN 'easy' WHEN random()<0.7 THEN 'normal' ELSE 'hard' END)
        WHEN 'level_end' THEN jsonb_build_object('level', floor(random()*10)+1, 'success', random()>0.2, 'score', floor(random()*1000))
        WHEN 'enemy_killed' THEN jsonb_build_object('enemy_type', CASE WHEN random()<0.5 THEN 'goblin' ELSE 'troll' END, 'position', jsonb_build_object('x', floor(random()*100), 'y', floor(random()*100)))
        WHEN 'item_collected' THEN jsonb_build_object('item', CASE WHEN random()<0.33 THEN 'coin' WHEN random()<0.66 THEN 'gem' ELSE 'key' END, 'value', floor(random()*50))
        WHEN 'player_died' THEN jsonb_build_object('position', jsonb_build_object('x', floor(random()*100), 'y', floor(random()*100)), 'enemy_nearby', random()>0.5)
        WHEN 'checkpoint_reached' THEN jsonb_build_object('checkpoint', floor(random()*5)+1)
        WHEN 'powerup_used' THEN jsonb_build_object('powerup', CASE WHEN random()<0.5 THEN 'shield' ELSE 'speed' END, 'duration', floor(random()*10)+5)
        ELSE '{}'::JSONB
    END;
    
    -- Вставляем событие
    INSERT INTO events (session_id, event_type, event_data, created_at)
    VALUES (p_session_id, selected_type, event_data, event_time);
END;
$$;


ALTER FUNCTION public.insert_random_event(p_session_id uuid, p_player_id text, session_start timestamp with time zone, session_end timestamp with time zone) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: adaptation_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.adaptation_history (
    history_id bigint NOT NULL,
    session_id uuid,
    player_id character varying(255),
    parameters jsonb,
    applied_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.adaptation_history OWNER TO postgres;

--
-- Name: adaptation_history_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.adaptation_history_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.adaptation_history_history_id_seq OWNER TO postgres;

--
-- Name: adaptation_history_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.adaptation_history_history_id_seq OWNED BY public.adaptation_history.history_id;


--
-- Name: adaptation_state; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.adaptation_state (
    adaptation_id bigint NOT NULL,
    session_id uuid,
    player_id character varying(255),
    parameters jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone
);


ALTER TABLE public.adaptation_state OWNER TO postgres;

--
-- Name: adaptation_state_adaptation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.adaptation_state_adaptation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.adaptation_state_adaptation_id_seq OWNER TO postgres;

--
-- Name: adaptation_state_adaptation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.adaptation_state_adaptation_id_seq OWNED BY public.adaptation_state.adaptation_id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.events (
    event_id bigint NOT NULL,
    session_id uuid,
    event_type character varying(100) NOT NULL,
    event_data jsonb,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.events OWNER TO postgres;

--
-- Name: events_event_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.events_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.events_event_id_seq OWNER TO postgres;

--
-- Name: events_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.events_event_id_seq OWNED BY public.events.event_id;


--
-- Name: players; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.players (
    player_id character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    last_session_id uuid,
    total_playtime interval
);


ALTER TABLE public.players OWNER TO postgres;

--
-- Name: predictions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.predictions (
    prediction_id bigint NOT NULL,
    session_id uuid,
    player_id character varying(255),
    prediction_type character varying(50) NOT NULL,
    prediction_value jsonb NOT NULL,
    model_version character varying(50),
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.predictions OWNER TO postgres;

--
-- Name: predictions_prediction_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.predictions_prediction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.predictions_prediction_id_seq OWNER TO postgres;

--
-- Name: predictions_prediction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.predictions_prediction_id_seq OWNED BY public.predictions.prediction_id;


--
-- Name: session_features; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session_features (
    feature_id bigint NOT NULL,
    session_id uuid NOT NULL,
    feature_name character varying(100) NOT NULL,
    feature_value numeric,
    calculated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.session_features OWNER TO postgres;

--
-- Name: session_features_feature_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.session_features_feature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.session_features_feature_id_seq OWNER TO postgres;

--
-- Name: session_features_feature_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.session_features_feature_id_seq OWNED BY public.session_features.feature_id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sessions (
    session_id uuid DEFAULT gen_random_uuid() NOT NULL,
    player_id character varying(255) NOT NULL,
    started_at timestamp with time zone DEFAULT now(),
    ended_at timestamp with time zone,
    game_version character varying(50)
);


ALTER TABLE public.sessions OWNER TO postgres;

--
-- Name: adaptation_history history_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adaptation_history ALTER COLUMN history_id SET DEFAULT nextval('public.adaptation_history_history_id_seq'::regclass);


--
-- Name: adaptation_state adaptation_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adaptation_state ALTER COLUMN adaptation_id SET DEFAULT nextval('public.adaptation_state_adaptation_id_seq'::regclass);


--
-- Name: events event_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events ALTER COLUMN event_id SET DEFAULT nextval('public.events_event_id_seq'::regclass);


--
-- Name: predictions prediction_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.predictions ALTER COLUMN prediction_id SET DEFAULT nextval('public.predictions_prediction_id_seq'::regclass);


--
-- Name: session_features feature_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_features ALTER COLUMN feature_id SET DEFAULT nextval('public.session_features_feature_id_seq'::regclass);


--
-- Data for Name: adaptation_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.adaptation_history (history_id, session_id, player_id, parameters, applied_at) FROM stdin;
\.


--
-- Data for Name: adaptation_state; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.adaptation_state (adaptation_id, session_id, player_id, parameters, updated_at, expires_at) FROM stdin;
\.


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.events (event_id, session_id, event_type, event_data, created_at) FROM stdin;
1	84527aad-b7d2-42ce-99be-c7663751a159	resume	{}	2026-02-17 07:47:12.441496+03
2	84527aad-b7d2-42ce-99be-c7663751a159	menu_open	{}	2026-02-17 07:53:03.917612+03
3	84527aad-b7d2-42ce-99be-c7663751a159	level_start	{"level": 7, "difficulty": "easy"}	2026-02-17 07:44:37.354303+03
4	84527aad-b7d2-42ce-99be-c7663751a159	enemy_killed	{"position": {"x": 95, "y": 58}, "enemy_type": "troll"}	2026-02-17 07:51:44.685943+03
5	84527aad-b7d2-42ce-99be-c7663751a159	level_end	{"level": 4, "score": 997, "success": false}	2026-02-17 07:45:11.71971+03
6	8767cd93-cb20-4018-bb77-490fe7f736a6	enemy_killed	{"position": {"x": 26, "y": 19}, "enemy_type": "troll"}	2026-03-16 02:14:33.296009+03
7	8767cd93-cb20-4018-bb77-490fe7f736a6	level_end	{"level": 8, "score": 853, "success": true}	2026-03-16 01:48:14.262407+03
8	8767cd93-cb20-4018-bb77-490fe7f736a6	enemy_killed	{"position": {"x": 29, "y": 66}, "enemy_type": "troll"}	2026-03-16 02:01:13.456344+03
9	8767cd93-cb20-4018-bb77-490fe7f736a6	pause	{}	2026-03-16 02:09:44.570052+03
10	8767cd93-cb20-4018-bb77-490fe7f736a6	enemy_killed	{"position": {"x": 75, "y": 29}, "enemy_type": "goblin"}	2026-03-16 02:16:56.389808+03
11	8767cd93-cb20-4018-bb77-490fe7f736a6	player_died	{"position": {"x": 40, "y": 59}, "enemy_nearby": true}	2026-03-16 01:42:40.387059+03
12	8767cd93-cb20-4018-bb77-490fe7f736a6	powerup_used	{"powerup": "speed", "duration": 6}	2026-03-16 02:11:41.705495+03
13	8767cd93-cb20-4018-bb77-490fe7f736a6	resume	{}	2026-03-16 01:47:33.63519+03
14	8767cd93-cb20-4018-bb77-490fe7f736a6	menu_open	{}	2026-03-16 02:20:14.412816+03
15	8767cd93-cb20-4018-bb77-490fe7f736a6	enemy_killed	{"position": {"x": 91, "y": 69}, "enemy_type": "troll"}	2026-03-16 02:07:56.195595+03
16	8767cd93-cb20-4018-bb77-490fe7f736a6	item_collected	{"item": "gem", "value": 15}	2026-03-16 02:01:00.584265+03
17	8767cd93-cb20-4018-bb77-490fe7f736a6	resume	{}	2026-03-16 02:05:54.12382+03
18	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	pause	{}	2026-03-09 02:56:25.886954+03
19	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	powerup_used	{"powerup": "shield", "duration": 14}	2026-03-09 02:54:10.277012+03
20	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	enemy_killed	{"position": {"x": 73, "y": 13}, "enemy_type": "troll"}	2026-03-09 03:07:01.827809+03
21	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	enemy_killed	{"position": {"x": 93, "y": 48}, "enemy_type": "troll"}	2026-03-09 03:11:14.923494+03
22	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	pause	{}	2026-03-09 03:04:27.062198+03
23	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	pause	{}	2026-03-09 02:57:10.9099+03
24	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	item_collected	{"item": "key", "value": 13}	2026-03-09 03:02:01.778404+03
25	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	menu_open	{}	2026-03-09 02:49:55.111584+03
26	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	level_end	{"level": 2, "score": 8, "success": true}	2026-03-09 02:54:26.60826+03
27	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	level_end	{"level": 5, "score": 72, "success": true}	2026-03-09 03:03:03.757713+03
28	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	level_end	{"level": 1, "score": 189, "success": true}	2026-03-09 03:10:13.649652+03
29	c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	pause	{}	2026-03-09 02:47:04.550299+03
30	19de7cd4-c9ed-4d17-881e-c608a33ff081	checkpoint_reached	{"checkpoint": 3}	2026-03-09 05:07:01.768422+03
31	19de7cd4-c9ed-4d17-881e-c608a33ff081	resume	{}	2026-03-09 05:04:11.04169+03
32	19de7cd4-c9ed-4d17-881e-c608a33ff081	powerup_used	{"powerup": "speed", "duration": 13}	2026-03-09 05:02:38.942033+03
33	19de7cd4-c9ed-4d17-881e-c608a33ff081	item_collected	{"item": "gem", "value": 5}	2026-03-09 05:01:54.618392+03
34	19de7cd4-c9ed-4d17-881e-c608a33ff081	player_died	{"position": {"x": 83, "y": 13}, "enemy_nearby": false}	2026-03-09 05:02:19.250918+03
35	19de7cd4-c9ed-4d17-881e-c608a33ff081	enemy_killed	{"position": {"x": 14, "y": 79}, "enemy_type": "goblin"}	2026-03-09 05:07:27.173844+03
36	19de7cd4-c9ed-4d17-881e-c608a33ff081	item_collected	{"item": "coin", "value": 31}	2026-03-09 05:03:46.189251+03
37	19de7cd4-c9ed-4d17-881e-c608a33ff081	level_end	{"level": 1, "score": 0, "success": true}	2026-03-09 05:02:22.45017+03
38	19de7cd4-c9ed-4d17-881e-c608a33ff081	pause	{}	2026-03-09 05:07:09.562472+03
39	19de7cd4-c9ed-4d17-881e-c608a33ff081	resume	{}	2026-03-09 05:06:09.41111+03
40	19de7cd4-c9ed-4d17-881e-c608a33ff081	item_collected	{"item": "gem", "value": 30}	2026-03-09 05:02:16.732501+03
41	19de7cd4-c9ed-4d17-881e-c608a33ff081	powerup_used	{"powerup": "speed", "duration": 5}	2026-03-09 05:04:50.249008+03
42	65865201-0ab0-49cc-bbbc-f57130f7c2ca	level_end	{"level": 5, "score": 517, "success": true}	2026-03-01 09:01:04.523826+03
43	65865201-0ab0-49cc-bbbc-f57130f7c2ca	menu_open	{}	2026-03-01 09:03:43.987545+03
44	65865201-0ab0-49cc-bbbc-f57130f7c2ca	menu_open	{}	2026-03-01 08:59:07.760598+03
45	65865201-0ab0-49cc-bbbc-f57130f7c2ca	enemy_killed	{"position": {"x": 23, "y": 71}, "enemy_type": "troll"}	2026-03-01 09:02:48.226511+03
46	65865201-0ab0-49cc-bbbc-f57130f7c2ca	menu_open	{}	2026-03-01 09:03:48.866229+03
47	65865201-0ab0-49cc-bbbc-f57130f7c2ca	level_start	{"level": 6, "difficulty": "hard"}	2026-03-01 08:49:15.739037+03
48	65865201-0ab0-49cc-bbbc-f57130f7c2ca	enemy_killed	{"position": {"x": 61, "y": 88}, "enemy_type": "troll"}	2026-03-01 09:00:20.107854+03
49	65865201-0ab0-49cc-bbbc-f57130f7c2ca	player_died	{"position": {"x": 24, "y": 87}, "enemy_nearby": false}	2026-03-01 09:02:57.560434+03
50	65865201-0ab0-49cc-bbbc-f57130f7c2ca	powerup_used	{"powerup": "speed", "duration": 5}	2026-03-01 08:49:00.519854+03
51	65865201-0ab0-49cc-bbbc-f57130f7c2ca	level_end	{"level": 6, "score": 814, "success": false}	2026-03-01 08:55:43.445403+03
52	65865201-0ab0-49cc-bbbc-f57130f7c2ca	player_died	{"position": {"x": 98, "y": 21}, "enemy_nearby": true}	2026-03-01 08:55:07.566456+03
53	65865201-0ab0-49cc-bbbc-f57130f7c2ca	powerup_used	{"powerup": "shield", "duration": 13}	2026-03-01 08:55:01.025932+03
54	65865201-0ab0-49cc-bbbc-f57130f7c2ca	enemy_killed	{"position": {"x": 81, "y": 35}, "enemy_type": "goblin"}	2026-03-01 09:05:21.736049+03
55	65865201-0ab0-49cc-bbbc-f57130f7c2ca	pause	{}	2026-03-01 09:00:07.333462+03
56	65865201-0ab0-49cc-bbbc-f57130f7c2ca	level_start	{"level": 10, "difficulty": "normal"}	2026-03-01 08:49:15.089086+03
57	65865201-0ab0-49cc-bbbc-f57130f7c2ca	resume	{}	2026-03-01 08:55:46.68903+03
58	65865201-0ab0-49cc-bbbc-f57130f7c2ca	checkpoint_reached	{"checkpoint": 3}	2026-03-01 08:57:02.314943+03
59	65865201-0ab0-49cc-bbbc-f57130f7c2ca	pause	{}	2026-03-01 09:03:05.616118+03
60	85d48362-04aa-4eb0-9404-cd7e95374bf3	level_start	{"level": 6, "difficulty": "normal"}	2026-02-16 05:57:08.177057+03
61	85d48362-04aa-4eb0-9404-cd7e95374bf3	player_died	{"position": {"x": 6, "y": 23}, "enemy_nearby": true}	2026-02-16 05:57:48.735519+03
62	85d48362-04aa-4eb0-9404-cd7e95374bf3	item_collected	{"item": "coin", "value": 26}	2026-02-16 05:55:05.387129+03
63	85d48362-04aa-4eb0-9404-cd7e95374bf3	level_end	{"level": 6, "score": 873, "success": true}	2026-02-16 05:58:01.199797+03
64	85d48362-04aa-4eb0-9404-cd7e95374bf3	powerup_used	{"powerup": "shield", "duration": 12}	2026-02-16 05:53:16.652329+03
65	85d48362-04aa-4eb0-9404-cd7e95374bf3	menu_open	{}	2026-02-16 05:49:02.11422+03
66	85d48362-04aa-4eb0-9404-cd7e95374bf3	menu_open	{}	2026-02-16 05:44:02.497384+03
67	85d48362-04aa-4eb0-9404-cd7e95374bf3	enemy_killed	{"position": {"x": 52, "y": 14}, "enemy_type": "goblin"}	2026-02-16 05:46:43.367875+03
68	85d48362-04aa-4eb0-9404-cd7e95374bf3	menu_open	{}	2026-02-16 05:43:40.179342+03
69	85d48362-04aa-4eb0-9404-cd7e95374bf3	powerup_used	{"powerup": "speed", "duration": 12}	2026-02-16 05:43:05.379866+03
70	85d48362-04aa-4eb0-9404-cd7e95374bf3	enemy_killed	{"position": {"x": 49, "y": 43}, "enemy_type": "goblin"}	2026-02-16 05:46:10.644289+03
71	85d48362-04aa-4eb0-9404-cd7e95374bf3	menu_open	{}	2026-02-16 05:42:24.818124+03
72	2a50968a-e764-4f78-9a3e-15e86cf6a168	menu_open	{}	2026-03-07 11:06:37.711992+03
73	2a50968a-e764-4f78-9a3e-15e86cf6a168	level_start	{"level": 7, "difficulty": "normal"}	2026-03-07 12:12:22.856367+03
74	2a50968a-e764-4f78-9a3e-15e86cf6a168	item_collected	{"item": "key", "value": 46}	2026-03-07 12:13:44.690182+03
75	2a50968a-e764-4f78-9a3e-15e86cf6a168	player_died	{"position": {"x": 52, "y": 38}, "enemy_nearby": true}	2026-03-07 10:42:56.428149+03
76	2a50968a-e764-4f78-9a3e-15e86cf6a168	player_died	{"position": {"x": 28, "y": 49}, "enemy_nearby": true}	2026-03-07 09:29:22.948514+03
77	2a50968a-e764-4f78-9a3e-15e86cf6a168	resume	{}	2026-03-07 11:34:54.359672+03
78	2a50968a-e764-4f78-9a3e-15e86cf6a168	powerup_used	{"powerup": "shield", "duration": 5}	2026-03-07 12:16:59.596586+03
79	2a50968a-e764-4f78-9a3e-15e86cf6a168	enemy_killed	{"position": {"x": 63, "y": 26}, "enemy_type": "troll"}	2026-03-07 07:46:56.97341+03
80	2a50968a-e764-4f78-9a3e-15e86cf6a168	player_died	{"position": {"x": 11, "y": 25}, "enemy_nearby": false}	2026-03-07 11:48:38.241837+03
81	2a50968a-e764-4f78-9a3e-15e86cf6a168	item_collected	{"item": "coin", "value": 17}	2026-03-07 10:56:41.021356+03
82	2a50968a-e764-4f78-9a3e-15e86cf6a168	powerup_used	{"powerup": "speed", "duration": 11}	2026-03-07 11:34:56.868215+03
83	348ca824-cf69-48e6-81e8-23c67b74b7d3	checkpoint_reached	{"checkpoint": 1}	2026-02-18 15:03:02.857409+03
84	348ca824-cf69-48e6-81e8-23c67b74b7d3	player_died	{"position": {"x": 76, "y": 2}, "enemy_nearby": false}	2026-02-18 15:08:28.176989+03
85	348ca824-cf69-48e6-81e8-23c67b74b7d3	checkpoint_reached	{"checkpoint": 1}	2026-02-18 14:57:45.836359+03
86	348ca824-cf69-48e6-81e8-23c67b74b7d3	enemy_killed	{"position": {"x": 20, "y": 98}, "enemy_type": "goblin"}	2026-02-18 14:31:31.001496+03
87	348ca824-cf69-48e6-81e8-23c67b74b7d3	level_start	{"level": 6, "difficulty": "easy"}	2026-02-18 14:52:54.576287+03
88	348ca824-cf69-48e6-81e8-23c67b74b7d3	resume	{}	2026-02-18 14:47:56.519984+03
89	348ca824-cf69-48e6-81e8-23c67b74b7d3	checkpoint_reached	{"checkpoint": 5}	2026-02-18 15:01:22.888976+03
90	348ca824-cf69-48e6-81e8-23c67b74b7d3	enemy_killed	{"position": {"x": 34, "y": 27}, "enemy_type": "goblin"}	2026-02-18 14:45:20.428159+03
91	348ca824-cf69-48e6-81e8-23c67b74b7d3	item_collected	{"item": "gem", "value": 13}	2026-02-18 14:42:54.407504+03
92	348ca824-cf69-48e6-81e8-23c67b74b7d3	powerup_used	{"powerup": "shield", "duration": 14}	2026-02-18 14:32:37.416081+03
93	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	powerup_used	{"powerup": "shield", "duration": 6}	2026-03-12 11:57:58.352592+03
94	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	checkpoint_reached	{"checkpoint": 5}	2026-03-12 11:52:54.767244+03
95	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	menu_open	{}	2026-03-12 11:57:06.457766+03
96	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	enemy_killed	{"position": {"x": 59, "y": 32}, "enemy_type": "troll"}	2026-03-12 11:57:04.380416+03
97	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	level_start	{"level": 7, "difficulty": "hard"}	2026-03-12 11:57:38.290201+03
98	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	item_collected	{"item": "key", "value": 15}	2026-03-12 11:55:07.810324+03
99	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	pause	{}	2026-03-12 11:55:59.620081+03
100	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	checkpoint_reached	{"checkpoint": 3}	2026-03-12 11:55:11.191266+03
101	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	resume	{}	2026-03-12 11:53:16.674252+03
102	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	level_end	{"level": 1, "score": 749, "success": true}	2026-03-12 11:54:31.181099+03
103	9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	item_collected	{"item": "coin", "value": 9}	2026-03-12 11:53:14.822899+03
104	ee3a21e0-4fad-44e6-b1ba-0125b697618c	level_start	{"level": 1, "difficulty": "easy"}	2026-03-05 19:39:26.998418+03
105	ee3a21e0-4fad-44e6-b1ba-0125b697618c	level_end	{"level": 6, "score": 81, "success": true}	2026-03-05 19:40:22.781029+03
106	ee3a21e0-4fad-44e6-b1ba-0125b697618c	menu_open	{}	2026-03-05 19:43:07.923536+03
107	ee3a21e0-4fad-44e6-b1ba-0125b697618c	item_collected	{"item": "gem", "value": 43}	2026-03-05 19:30:35.685561+03
108	ee3a21e0-4fad-44e6-b1ba-0125b697618c	item_collected	{"item": "gem", "value": 40}	2026-03-05 19:44:04.332165+03
109	ee3a21e0-4fad-44e6-b1ba-0125b697618c	menu_open	{}	2026-03-05 19:26:48.332995+03
110	ee3a21e0-4fad-44e6-b1ba-0125b697618c	player_died	{"position": {"x": 99, "y": 90}, "enemy_nearby": false}	2026-03-05 19:34:11.494314+03
111	ee3a21e0-4fad-44e6-b1ba-0125b697618c	level_end	{"level": 7, "score": 375, "success": false}	2026-03-05 19:45:02.642092+03
112	ee3a21e0-4fad-44e6-b1ba-0125b697618c	menu_open	{}	2026-03-05 19:43:43.046333+03
113	1767d3bb-8172-487a-84b6-d01c1bca5826	level_start	{"level": 6, "difficulty": "normal"}	2026-02-25 15:54:31.943367+03
114	1767d3bb-8172-487a-84b6-d01c1bca5826	resume	{}	2026-02-25 15:58:08.302459+03
115	1767d3bb-8172-487a-84b6-d01c1bca5826	checkpoint_reached	{"checkpoint": 4}	2026-02-25 15:53:56.963281+03
116	1767d3bb-8172-487a-84b6-d01c1bca5826	resume	{}	2026-02-25 15:59:21.68353+03
117	1767d3bb-8172-487a-84b6-d01c1bca5826	item_collected	{"item": "coin", "value": 36}	2026-02-25 15:51:25.564452+03
118	1767d3bb-8172-487a-84b6-d01c1bca5826	item_collected	{"item": "gem", "value": 43}	2026-02-25 16:12:42.400336+03
119	1767d3bb-8172-487a-84b6-d01c1bca5826	menu_open	{}	2026-02-25 16:00:02.6322+03
120	1767d3bb-8172-487a-84b6-d01c1bca5826	powerup_used	{"powerup": "shield", "duration": 13}	2026-02-25 15:49:49.445243+03
121	9331511e-e127-4b41-be2f-8285e6767392	menu_open	{}	2026-03-16 19:38:01.263812+03
122	9331511e-e127-4b41-be2f-8285e6767392	checkpoint_reached	{"checkpoint": 3}	2026-03-16 19:57:04.378695+03
123	9331511e-e127-4b41-be2f-8285e6767392	menu_open	{}	2026-03-16 19:55:44.382702+03
124	9331511e-e127-4b41-be2f-8285e6767392	level_end	{"level": 3, "score": 987, "success": false}	2026-03-16 19:51:11.410764+03
125	9331511e-e127-4b41-be2f-8285e6767392	resume	{}	2026-03-16 19:47:20.289596+03
126	9331511e-e127-4b41-be2f-8285e6767392	item_collected	{"item": "coin", "value": 3}	2026-03-16 19:35:50.3961+03
127	9331511e-e127-4b41-be2f-8285e6767392	pause	{}	2026-03-16 19:51:08.591484+03
128	9331511e-e127-4b41-be2f-8285e6767392	player_died	{"position": {"x": 22, "y": 5}, "enemy_nearby": true}	2026-03-16 19:43:57.900013+03
129	9331511e-e127-4b41-be2f-8285e6767392	resume	{}	2026-03-16 19:38:14.712152+03
130	9331511e-e127-4b41-be2f-8285e6767392	level_start	{"level": 3, "difficulty": "hard"}	2026-03-16 19:52:01.656504+03
131	9331511e-e127-4b41-be2f-8285e6767392	item_collected	{"item": "coin", "value": 20}	2026-03-16 19:33:38.857726+03
132	9331511e-e127-4b41-be2f-8285e6767392	checkpoint_reached	{"checkpoint": 1}	2026-03-16 19:40:04.783339+03
133	9331511e-e127-4b41-be2f-8285e6767392	menu_open	{}	2026-03-16 19:56:24.393402+03
134	9331511e-e127-4b41-be2f-8285e6767392	powerup_used	{"powerup": "shield", "duration": 10}	2026-03-16 19:48:28.51661+03
135	9331511e-e127-4b41-be2f-8285e6767392	pause	{}	2026-03-16 19:42:32.056424+03
136	9331511e-e127-4b41-be2f-8285e6767392	level_start	{"level": 9, "difficulty": "hard"}	2026-03-16 19:36:28.233164+03
137	9331511e-e127-4b41-be2f-8285e6767392	level_start	{"level": 8, "difficulty": "normal"}	2026-03-16 19:42:04.616496+03
138	9331511e-e127-4b41-be2f-8285e6767392	enemy_killed	{"position": {"x": 31, "y": 49}, "enemy_type": "goblin"}	2026-03-16 19:39:30.635951+03
139	9331511e-e127-4b41-be2f-8285e6767392	level_start	{"level": 2, "difficulty": "normal"}	2026-03-16 19:42:14.558533+03
140	9331511e-e127-4b41-be2f-8285e6767392	item_collected	{"item": "gem", "value": 41}	2026-03-16 19:40:30.055157+03
141	b4ee6051-9957-4887-b1bc-30ef3771f951	item_collected	{"item": "coin", "value": 26}	2026-03-10 17:29:13.106246+03
142	b4ee6051-9957-4887-b1bc-30ef3771f951	checkpoint_reached	{"checkpoint": 1}	2026-03-10 17:32:16.946749+03
143	b4ee6051-9957-4887-b1bc-30ef3771f951	menu_open	{}	2026-03-10 17:37:28.17073+03
144	b4ee6051-9957-4887-b1bc-30ef3771f951	checkpoint_reached	{"checkpoint": 5}	2026-03-10 17:26:43.61979+03
145	b4ee6051-9957-4887-b1bc-30ef3771f951	enemy_killed	{"position": {"x": 79, "y": 56}, "enemy_type": "goblin"}	2026-03-10 17:28:23.326846+03
146	b4ee6051-9957-4887-b1bc-30ef3771f951	resume	{}	2026-03-10 17:27:52.028804+03
147	b4ee6051-9957-4887-b1bc-30ef3771f951	level_start	{"level": 10, "difficulty": "easy"}	2026-03-10 17:29:11.345306+03
148	b4ee6051-9957-4887-b1bc-30ef3771f951	checkpoint_reached	{"checkpoint": 2}	2026-03-10 17:28:19.60659+03
149	b4ee6051-9957-4887-b1bc-30ef3771f951	resume	{}	2026-03-10 17:37:57.405702+03
150	b4ee6051-9957-4887-b1bc-30ef3771f951	item_collected	{"item": "coin", "value": 46}	2026-03-10 17:36:28.953208+03
151	b4ee6051-9957-4887-b1bc-30ef3771f951	resume	{}	2026-03-10 17:30:23.673795+03
152	b4ee6051-9957-4887-b1bc-30ef3771f951	resume	{}	2026-03-10 17:38:09.233349+03
153	b4ee6051-9957-4887-b1bc-30ef3771f951	pause	{}	2026-03-10 17:28:07.477366+03
154	b4ee6051-9957-4887-b1bc-30ef3771f951	player_died	{"position": {"x": 35, "y": 10}, "enemy_nearby": true}	2026-03-10 17:29:36.915383+03
155	b4ee6051-9957-4887-b1bc-30ef3771f951	level_start	{"level": 7, "difficulty": "easy"}	2026-03-10 17:22:50.583906+03
156	b4ee6051-9957-4887-b1bc-30ef3771f951	resume	{}	2026-03-10 17:33:19.158672+03
157	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	item_collected	{"item": "coin", "value": 30}	2026-03-10 22:33:24.767917+03
158	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	checkpoint_reached	{"checkpoint": 5}	2026-03-10 21:57:19.188651+03
159	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	level_end	{"level": 5, "score": 975, "success": true}	2026-03-10 22:22:05.988785+03
160	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	level_start	{"level": 1, "difficulty": "normal"}	2026-03-10 22:24:22.777825+03
161	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	level_end	{"level": 5, "score": 551, "success": true}	2026-03-10 22:02:51.922738+03
162	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	player_died	{"position": {"x": 97, "y": 32}, "enemy_nearby": false}	2026-03-10 22:07:56.927827+03
163	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	menu_open	{}	2026-03-10 22:23:48.753255+03
164	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	item_collected	{"item": "gem", "value": 19}	2026-03-10 22:20:32.711496+03
165	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	powerup_used	{"powerup": "shield", "duration": 8}	2026-03-10 22:33:36.429243+03
166	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	player_died	{"position": {"x": 64, "y": 33}, "enemy_nearby": true}	2026-03-10 21:51:02.143061+03
167	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	checkpoint_reached	{"checkpoint": 4}	2026-03-10 22:17:10.823862+03
168	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	level_start	{"level": 4, "difficulty": "easy"}	2026-03-10 21:51:48.440932+03
169	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	powerup_used	{"powerup": "speed", "duration": 12}	2026-03-10 22:09:08.967683+03
170	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	enemy_killed	{"position": {"x": 1, "y": 78}, "enemy_type": "goblin"}	2026-03-10 22:04:57.926638+03
171	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	menu_open	{}	2026-03-10 21:53:47.349569+03
172	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	level_end	{"level": 5, "score": 522, "success": true}	2026-03-10 22:23:12.716976+03
173	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	pause	{}	2026-03-10 22:14:50.11065+03
174	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	powerup_used	{"powerup": "shield", "duration": 9}	2026-03-10 22:33:55.859185+03
175	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	menu_open	{}	2026-03-10 22:11:05.100681+03
176	f8cdc801-12ec-4a18-9fee-0bdb0d37961c	level_end	{"level": 6, "score": 413, "success": true}	2026-03-10 22:21:08.370044+03
177	d4724f70-dffc-4c62-a196-b0e6deed6dce	item_collected	{"item": "gem", "value": 29}	2026-03-10 18:12:54.063276+03
178	d4724f70-dffc-4c62-a196-b0e6deed6dce	enemy_killed	{"position": {"x": 92, "y": 72}, "enemy_type": "troll"}	2026-03-10 17:52:24.211218+03
179	d4724f70-dffc-4c62-a196-b0e6deed6dce	menu_open	{}	2026-03-10 18:20:55.481992+03
180	d4724f70-dffc-4c62-a196-b0e6deed6dce	player_died	{"position": {"x": 96, "y": 17}, "enemy_nearby": true}	2026-03-10 18:16:38.47894+03
181	d4724f70-dffc-4c62-a196-b0e6deed6dce	checkpoint_reached	{"checkpoint": 4}	2026-03-10 18:18:22.811577+03
182	d4724f70-dffc-4c62-a196-b0e6deed6dce	powerup_used	{"powerup": "shield", "duration": 13}	2026-03-10 18:12:37.852394+03
183	d4724f70-dffc-4c62-a196-b0e6deed6dce	enemy_killed	{"position": {"x": 13, "y": 75}, "enemy_type": "troll"}	2026-03-10 18:18:42.228667+03
184	d4724f70-dffc-4c62-a196-b0e6deed6dce	player_died	{"position": {"x": 3, "y": 10}, "enemy_nearby": false}	2026-03-10 18:09:26.933232+03
185	d4724f70-dffc-4c62-a196-b0e6deed6dce	level_end	{"level": 2, "score": 308, "success": true}	2026-03-10 18:04:49.127939+03
186	d4724f70-dffc-4c62-a196-b0e6deed6dce	level_start	{"level": 7, "difficulty": "normal"}	2026-03-10 17:47:30.839839+03
187	d4724f70-dffc-4c62-a196-b0e6deed6dce	menu_open	{}	2026-03-10 17:58:25.9756+03
188	d4724f70-dffc-4c62-a196-b0e6deed6dce	item_collected	{"item": "gem", "value": 11}	2026-03-10 18:17:10.960109+03
189	d4724f70-dffc-4c62-a196-b0e6deed6dce	level_start	{"level": 6, "difficulty": "normal"}	2026-03-10 17:50:35.506319+03
190	d4724f70-dffc-4c62-a196-b0e6deed6dce	level_start	{"level": 2, "difficulty": "normal"}	2026-03-10 18:04:50.111013+03
191	d4724f70-dffc-4c62-a196-b0e6deed6dce	checkpoint_reached	{"checkpoint": 1}	2026-03-10 18:16:33.384113+03
192	d4724f70-dffc-4c62-a196-b0e6deed6dce	menu_open	{}	2026-03-10 17:42:53.479633+03
193	ef51adb8-14a6-4af8-8d96-268d8ca1e436	player_died	{"position": {"x": 35, "y": 3}, "enemy_nearby": true}	2026-03-12 06:30:48.515713+03
194	ef51adb8-14a6-4af8-8d96-268d8ca1e436	player_died	{"position": {"x": 62, "y": 86}, "enemy_nearby": true}	2026-03-12 06:49:53.993926+03
195	ef51adb8-14a6-4af8-8d96-268d8ca1e436	enemy_killed	{"position": {"x": 57, "y": 33}, "enemy_type": "troll"}	2026-03-12 06:57:59.976315+03
196	ef51adb8-14a6-4af8-8d96-268d8ca1e436	item_collected	{"item": "coin", "value": 32}	2026-03-12 06:38:17.051657+03
197	ef51adb8-14a6-4af8-8d96-268d8ca1e436	powerup_used	{"powerup": "shield", "duration": 14}	2026-03-12 06:48:19.047924+03
198	ef51adb8-14a6-4af8-8d96-268d8ca1e436	pause	{}	2026-03-12 06:32:20.843945+03
199	ef51adb8-14a6-4af8-8d96-268d8ca1e436	level_end	{"level": 4, "score": 25, "success": true}	2026-03-12 06:57:03.413096+03
200	6634dee1-6f84-4729-b002-77e4e37081da	resume	{}	2026-03-03 15:32:33.198854+03
201	6634dee1-6f84-4729-b002-77e4e37081da	enemy_killed	{"position": {"x": 77, "y": 56}, "enemy_type": "troll"}	2026-03-03 15:45:14.576683+03
202	6634dee1-6f84-4729-b002-77e4e37081da	checkpoint_reached	{"checkpoint": 2}	2026-03-03 16:04:58.53133+03
203	6634dee1-6f84-4729-b002-77e4e37081da	resume	{}	2026-03-03 15:42:12.776886+03
204	6634dee1-6f84-4729-b002-77e4e37081da	checkpoint_reached	{"checkpoint": 3}	2026-03-03 15:40:24.141101+03
205	6634dee1-6f84-4729-b002-77e4e37081da	enemy_killed	{"position": {"x": 84, "y": 55}, "enemy_type": "goblin"}	2026-03-03 15:35:11.71798+03
206	6634dee1-6f84-4729-b002-77e4e37081da	powerup_used	{"powerup": "shield", "duration": 10}	2026-03-03 15:36:08.796705+03
207	b9314229-8b2b-45a7-815f-3f5394a124aa	level_end	{"level": 8, "score": 44, "success": true}	2026-03-02 08:53:41.469958+03
208	b9314229-8b2b-45a7-815f-3f5394a124aa	item_collected	{"item": "coin", "value": 31}	2026-03-02 08:54:15.500472+03
209	b9314229-8b2b-45a7-815f-3f5394a124aa	level_end	{"level": 6, "score": 766, "success": true}	2026-03-02 08:55:55.006701+03
210	b9314229-8b2b-45a7-815f-3f5394a124aa	checkpoint_reached	{"checkpoint": 5}	2026-03-02 08:54:44.190743+03
211	b9314229-8b2b-45a7-815f-3f5394a124aa	player_died	{"position": {"x": 78, "y": 42}, "enemy_nearby": true}	2026-03-02 08:54:06.601148+03
212	b9314229-8b2b-45a7-815f-3f5394a124aa	level_start	{"level": 7, "difficulty": "easy"}	2026-03-02 08:52:04.263707+03
213	b9314229-8b2b-45a7-815f-3f5394a124aa	powerup_used	{"powerup": "shield", "duration": 8}	2026-03-02 08:53:38.828501+03
214	b9314229-8b2b-45a7-815f-3f5394a124aa	powerup_used	{"powerup": "speed", "duration": 13}	2026-03-02 08:54:04.889396+03
215	b9314229-8b2b-45a7-815f-3f5394a124aa	player_died	{"position": {"x": 16, "y": 4}, "enemy_nearby": false}	2026-03-02 08:55:25.658695+03
216	b9314229-8b2b-45a7-815f-3f5394a124aa	resume	{}	2026-03-02 08:55:44.456082+03
217	b9314229-8b2b-45a7-815f-3f5394a124aa	checkpoint_reached	{"checkpoint": 4}	2026-03-02 08:53:30.947176+03
218	b9314229-8b2b-45a7-815f-3f5394a124aa	powerup_used	{"powerup": "speed", "duration": 8}	2026-03-02 08:56:54.790656+03
219	b9314229-8b2b-45a7-815f-3f5394a124aa	powerup_used	{"powerup": "shield", "duration": 9}	2026-03-02 08:56:06.309702+03
220	b9314229-8b2b-45a7-815f-3f5394a124aa	level_start	{"level": 7, "difficulty": "normal"}	2026-03-02 08:51:38.874852+03
221	b9314229-8b2b-45a7-815f-3f5394a124aa	level_end	{"level": 8, "score": 874, "success": true}	2026-03-02 08:56:33.324102+03
222	b9314229-8b2b-45a7-815f-3f5394a124aa	resume	{}	2026-03-02 08:56:55.784294+03
223	b9314229-8b2b-45a7-815f-3f5394a124aa	item_collected	{"item": "gem", "value": 13}	2026-03-02 08:55:15.568045+03
224	b9314229-8b2b-45a7-815f-3f5394a124aa	checkpoint_reached	{"checkpoint": 5}	2026-03-02 08:52:06.843578+03
225	5244b4d7-59e0-4922-936e-026430b6df09	enemy_killed	{"position": {"x": 34, "y": 46}, "enemy_type": "troll"}	2026-03-12 17:14:25.377078+03
226	5244b4d7-59e0-4922-936e-026430b6df09	pause	{}	2026-03-12 17:09:56.360576+03
227	5244b4d7-59e0-4922-936e-026430b6df09	checkpoint_reached	{"checkpoint": 1}	2026-03-12 17:12:08.567664+03
228	5244b4d7-59e0-4922-936e-026430b6df09	item_collected	{"item": "coin", "value": 46}	2026-03-12 17:00:26.55167+03
229	5244b4d7-59e0-4922-936e-026430b6df09	player_died	{"position": {"x": 36, "y": 15}, "enemy_nearby": true}	2026-03-12 17:03:19.949698+03
230	5244b4d7-59e0-4922-936e-026430b6df09	item_collected	{"item": "gem", "value": 43}	2026-03-12 17:08:08.302595+03
231	5244b4d7-59e0-4922-936e-026430b6df09	powerup_used	{"powerup": "shield", "duration": 8}	2026-03-12 17:11:54.33105+03
232	5244b4d7-59e0-4922-936e-026430b6df09	level_end	{"level": 9, "score": 263, "success": true}	2026-03-12 17:12:40.691762+03
233	5244b4d7-59e0-4922-936e-026430b6df09	level_end	{"level": 4, "score": 794, "success": true}	2026-03-12 17:06:15.205537+03
234	5244b4d7-59e0-4922-936e-026430b6df09	resume	{}	2026-03-12 16:58:08.220625+03
235	5244b4d7-59e0-4922-936e-026430b6df09	resume	{}	2026-03-12 17:14:34.294794+03
236	5244b4d7-59e0-4922-936e-026430b6df09	enemy_killed	{"position": {"x": 58, "y": 52}, "enemy_type": "troll"}	2026-03-12 17:03:18.309417+03
237	5244b4d7-59e0-4922-936e-026430b6df09	checkpoint_reached	{"checkpoint": 4}	2026-03-12 17:13:56.615573+03
238	5244b4d7-59e0-4922-936e-026430b6df09	player_died	{"position": {"x": 51, "y": 49}, "enemy_nearby": true}	2026-03-12 17:00:55.734218+03
239	5244b4d7-59e0-4922-936e-026430b6df09	enemy_killed	{"position": {"x": 30, "y": 98}, "enemy_type": "goblin"}	2026-03-12 17:12:06.222985+03
240	5244b4d7-59e0-4922-936e-026430b6df09	item_collected	{"item": "gem", "value": 22}	2026-03-12 17:16:06.677594+03
241	fb742483-f64d-4932-9581-5b6ad40b92cc	item_collected	{"item": "gem", "value": 25}	2026-02-25 03:27:59.457749+03
242	fb742483-f64d-4932-9581-5b6ad40b92cc	enemy_killed	{"position": {"x": 73, "y": 64}, "enemy_type": "troll"}	2026-02-25 03:32:07.628633+03
243	fb742483-f64d-4932-9581-5b6ad40b92cc	item_collected	{"item": "gem", "value": 18}	2026-02-25 03:20:49.448053+03
244	fb742483-f64d-4932-9581-5b6ad40b92cc	level_start	{"level": 3, "difficulty": "normal"}	2026-02-25 03:28:34.172268+03
245	fb742483-f64d-4932-9581-5b6ad40b92cc	menu_open	{}	2026-02-25 03:19:10.378182+03
246	fb742483-f64d-4932-9581-5b6ad40b92cc	player_died	{"position": {"x": 15, "y": 12}, "enemy_nearby": true}	2026-02-25 03:35:32.299223+03
247	fb742483-f64d-4932-9581-5b6ad40b92cc	powerup_used	{"powerup": "shield", "duration": 6}	2026-02-25 03:22:33.94268+03
248	fb742483-f64d-4932-9581-5b6ad40b92cc	enemy_killed	{"position": {"x": 7, "y": 46}, "enemy_type": "goblin"}	2026-02-25 03:28:26.232457+03
249	fb742483-f64d-4932-9581-5b6ad40b92cc	menu_open	{}	2026-02-25 03:35:20.437823+03
250	fb742483-f64d-4932-9581-5b6ad40b92cc	level_start	{"level": 9, "difficulty": "normal"}	2026-02-25 03:21:58.190855+03
251	fb742483-f64d-4932-9581-5b6ad40b92cc	enemy_killed	{"position": {"x": 24, "y": 20}, "enemy_type": "goblin"}	2026-02-25 03:23:16.719738+03
252	fb742483-f64d-4932-9581-5b6ad40b92cc	level_end	{"level": 7, "score": 495, "success": true}	2026-02-25 03:35:04.332113+03
253	fb742483-f64d-4932-9581-5b6ad40b92cc	item_collected	{"item": "coin", "value": 43}	2026-02-25 03:25:53.277312+03
254	fb742483-f64d-4932-9581-5b6ad40b92cc	level_start	{"level": 2, "difficulty": "normal"}	2026-02-25 03:29:41.746898+03
255	c0668173-ffe1-47b9-9619-9da7da7cc2bf	powerup_used	{"powerup": "shield", "duration": 6}	2026-03-10 23:13:29.545872+03
256	c0668173-ffe1-47b9-9619-9da7da7cc2bf	level_start	{"level": 4, "difficulty": "hard"}	2026-03-10 22:01:07.817346+03
257	c0668173-ffe1-47b9-9619-9da7da7cc2bf	menu_open	{}	2026-03-11 00:18:43.056366+03
258	c0668173-ffe1-47b9-9619-9da7da7cc2bf	player_died	{"position": {"x": 59, "y": 62}, "enemy_nearby": true}	2026-03-10 21:47:47.384631+03
259	c0668173-ffe1-47b9-9619-9da7da7cc2bf	pause	{}	2026-03-10 22:39:13.209333+03
260	c0668173-ffe1-47b9-9619-9da7da7cc2bf	player_died	{"position": {"x": 63, "y": 6}, "enemy_nearby": true}	2026-03-10 23:30:30.185727+03
261	c0668173-ffe1-47b9-9619-9da7da7cc2bf	resume	{}	2026-03-11 00:39:16.562362+03
262	c0668173-ffe1-47b9-9619-9da7da7cc2bf	pause	{}	2026-03-10 21:45:02.624624+03
263	c0668173-ffe1-47b9-9619-9da7da7cc2bf	checkpoint_reached	{"checkpoint": 1}	2026-03-10 21:30:54.994316+03
264	c0668173-ffe1-47b9-9619-9da7da7cc2bf	pause	{}	2026-03-10 21:58:58.207384+03
265	c0668173-ffe1-47b9-9619-9da7da7cc2bf	level_start	{"level": 5, "difficulty": "normal"}	2026-03-10 21:56:32.714874+03
266	c0668173-ffe1-47b9-9619-9da7da7cc2bf	checkpoint_reached	{"checkpoint": 2}	2026-03-10 22:52:02.471103+03
267	c0668173-ffe1-47b9-9619-9da7da7cc2bf	resume	{}	2026-03-10 22:11:12.540024+03
268	c0668173-ffe1-47b9-9619-9da7da7cc2bf	player_died	{"position": {"x": 38, "y": 5}, "enemy_nearby": true}	2026-03-10 23:22:17.736019+03
269	c0668173-ffe1-47b9-9619-9da7da7cc2bf	enemy_killed	{"position": {"x": 72, "y": 67}, "enemy_type": "troll"}	2026-03-11 00:53:28.042764+03
270	a46edd96-cbc8-4eea-bc43-9a95e55b42c3	powerup_used	{"powerup": "speed", "duration": 6}	2026-02-16 02:55:33.987516+03
271	a46edd96-cbc8-4eea-bc43-9a95e55b42c3	enemy_killed	{"position": {"x": 72, "y": 82}, "enemy_type": "troll"}	2026-02-16 03:03:48.182161+03
272	a46edd96-cbc8-4eea-bc43-9a95e55b42c3	checkpoint_reached	{"checkpoint": 2}	2026-02-16 02:55:27.322598+03
273	a46edd96-cbc8-4eea-bc43-9a95e55b42c3	checkpoint_reached	{"checkpoint": 4}	2026-02-16 03:06:17.906966+03
274	a46edd96-cbc8-4eea-bc43-9a95e55b42c3	level_end	{"level": 3, "score": 636, "success": true}	2026-02-16 03:10:55.626786+03
275	a46edd96-cbc8-4eea-bc43-9a95e55b42c3	powerup_used	{"powerup": "shield", "duration": 11}	2026-02-16 03:12:07.1724+03
276	a46edd96-cbc8-4eea-bc43-9a95e55b42c3	level_start	{"level": 8, "difficulty": "normal"}	2026-02-16 03:10:37.522076+03
277	a46edd96-cbc8-4eea-bc43-9a95e55b42c3	level_start	{"level": 1, "difficulty": "hard"}	2026-02-16 03:03:37.419723+03
278	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	item_collected	{"item": "gem", "value": 13}	2026-02-16 15:44:57.000886+03
279	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	pause	{}	2026-02-16 15:38:40.858649+03
280	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	powerup_used	{"powerup": "shield", "duration": 8}	2026-02-16 15:20:05.150303+03
281	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	menu_open	{}	2026-02-16 15:47:19.531321+03
282	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	level_start	{"level": 7, "difficulty": "normal"}	2026-02-16 15:41:55.213537+03
283	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	menu_open	{}	2026-02-16 15:24:11.26908+03
284	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	player_died	{"position": {"x": 9, "y": 43}, "enemy_nearby": false}	2026-02-16 15:40:44.231519+03
285	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	resume	{}	2026-02-16 15:23:41.907031+03
286	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	pause	{}	2026-02-16 15:26:21.712272+03
287	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	powerup_used	{"powerup": "shield", "duration": 8}	2026-02-16 15:33:29.752078+03
288	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	enemy_killed	{"position": {"x": 54, "y": 50}, "enemy_type": "troll"}	2026-02-16 15:50:05.115529+03
289	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	item_collected	{"item": "key", "value": 2}	2026-02-16 15:29:05.638313+03
290	ab6908e7-2b42-4617-b06d-ece8bfb2cccd	checkpoint_reached	{"checkpoint": 3}	2026-02-16 15:44:05.171987+03
291	9ee44003-00e7-4c49-94e8-74b44f116f12	resume	{}	2026-03-10 11:27:49.193889+03
292	9ee44003-00e7-4c49-94e8-74b44f116f12	item_collected	{"item": "key", "value": 48}	2026-03-10 11:31:36.492255+03
293	9ee44003-00e7-4c49-94e8-74b44f116f12	checkpoint_reached	{"checkpoint": 2}	2026-03-10 11:44:55.739058+03
294	9ee44003-00e7-4c49-94e8-74b44f116f12	powerup_used	{"powerup": "shield", "duration": 7}	2026-03-10 11:41:08.183638+03
295	9ee44003-00e7-4c49-94e8-74b44f116f12	menu_open	{}	2026-03-10 11:29:45.399492+03
296	9ee44003-00e7-4c49-94e8-74b44f116f12	menu_open	{}	2026-03-10 11:35:36.09405+03
297	74e35c49-1e10-44b4-bda8-4052aa441baf	resume	{}	2026-03-04 11:18:53.574218+03
298	74e35c49-1e10-44b4-bda8-4052aa441baf	pause	{}	2026-03-04 11:19:36.950341+03
299	74e35c49-1e10-44b4-bda8-4052aa441baf	resume	{}	2026-03-04 09:46:10.608854+03
300	74e35c49-1e10-44b4-bda8-4052aa441baf	level_end	{"level": 5, "score": 703, "success": true}	2026-03-04 10:24:38.934685+03
301	74e35c49-1e10-44b4-bda8-4052aa441baf	level_end	{"level": 7, "score": 643, "success": true}	2026-03-04 11:03:42.52793+03
302	74e35c49-1e10-44b4-bda8-4052aa441baf	player_died	{"position": {"x": 65, "y": 84}, "enemy_nearby": true}	2026-03-04 11:47:36.243434+03
303	74e35c49-1e10-44b4-bda8-4052aa441baf	level_start	{"level": 6, "difficulty": "easy"}	2026-03-04 09:56:09.148078+03
304	74e35c49-1e10-44b4-bda8-4052aa441baf	enemy_killed	{"position": {"x": 22, "y": 16}, "enemy_type": "goblin"}	2026-03-04 09:55:30.819561+03
305	74e35c49-1e10-44b4-bda8-4052aa441baf	menu_open	{}	2026-03-04 11:21:38.244574+03
306	74e35c49-1e10-44b4-bda8-4052aa441baf	checkpoint_reached	{"checkpoint": 3}	2026-03-04 11:43:36.085269+03
307	74e35c49-1e10-44b4-bda8-4052aa441baf	checkpoint_reached	{"checkpoint": 5}	2026-03-04 09:38:30.868544+03
308	74e35c49-1e10-44b4-bda8-4052aa441baf	item_collected	{"item": "key", "value": 18}	2026-03-04 10:00:28.143593+03
309	74e35c49-1e10-44b4-bda8-4052aa441baf	player_died	{"position": {"x": 63, "y": 47}, "enemy_nearby": true}	2026-03-04 09:28:32.766329+03
310	ad52df3e-a9d0-4818-bce5-ed472bd371c0	resume	{}	2026-03-11 01:46:13.640458+03
311	ad52df3e-a9d0-4818-bce5-ed472bd371c0	resume	{}	2026-03-11 02:45:31.887446+03
312	ad52df3e-a9d0-4818-bce5-ed472bd371c0	powerup_used	{"powerup": "shield", "duration": 14}	2026-03-11 02:06:07.324656+03
313	ad52df3e-a9d0-4818-bce5-ed472bd371c0	resume	{}	2026-03-11 01:02:17.701667+03
314	ad52df3e-a9d0-4818-bce5-ed472bd371c0	player_died	{"position": {"x": 33, "y": 76}, "enemy_nearby": false}	2026-03-11 02:53:31.539065+03
315	ad52df3e-a9d0-4818-bce5-ed472bd371c0	pause	{}	2026-03-11 01:48:06.187466+03
316	ad52df3e-a9d0-4818-bce5-ed472bd371c0	menu_open	{}	2026-03-11 01:46:13.014523+03
317	ad52df3e-a9d0-4818-bce5-ed472bd371c0	enemy_killed	{"position": {"x": 60, "y": 90}, "enemy_type": "troll"}	2026-03-11 00:20:39.51811+03
318	ad52df3e-a9d0-4818-bce5-ed472bd371c0	resume	{}	2026-03-11 00:59:38.402804+03
319	100daaff-d23e-412c-b135-44eb853b9a1a	level_start	{"level": 10, "difficulty": "hard"}	2026-03-08 23:37:50.860696+03
320	100daaff-d23e-412c-b135-44eb853b9a1a	level_start	{"level": 2, "difficulty": "normal"}	2026-03-08 23:40:59.891841+03
321	100daaff-d23e-412c-b135-44eb853b9a1a	checkpoint_reached	{"checkpoint": 3}	2026-03-08 23:26:17.245911+03
322	100daaff-d23e-412c-b135-44eb853b9a1a	enemy_killed	{"position": {"x": 72, "y": 40}, "enemy_type": "goblin"}	2026-03-08 23:25:50.294588+03
323	100daaff-d23e-412c-b135-44eb853b9a1a	menu_open	{}	2026-03-08 23:19:47.316957+03
324	100daaff-d23e-412c-b135-44eb853b9a1a	menu_open	{}	2026-03-08 23:21:11.975133+03
325	100daaff-d23e-412c-b135-44eb853b9a1a	checkpoint_reached	{"checkpoint": 1}	2026-03-08 23:28:11.38238+03
326	100daaff-d23e-412c-b135-44eb853b9a1a	level_start	{"level": 8, "difficulty": "normal"}	2026-03-08 23:32:54.473025+03
327	100daaff-d23e-412c-b135-44eb853b9a1a	level_end	{"level": 6, "score": 653, "success": false}	2026-03-08 23:21:28.341906+03
328	100daaff-d23e-412c-b135-44eb853b9a1a	level_end	{"level": 10, "score": 555, "success": true}	2026-03-08 23:13:56.519042+03
329	100daaff-d23e-412c-b135-44eb853b9a1a	checkpoint_reached	{"checkpoint": 3}	2026-03-08 23:17:49.813698+03
330	100daaff-d23e-412c-b135-44eb853b9a1a	item_collected	{"item": "coin", "value": 32}	2026-03-08 23:21:53.262815+03
331	100daaff-d23e-412c-b135-44eb853b9a1a	pause	{}	2026-03-08 23:15:43.64292+03
332	100daaff-d23e-412c-b135-44eb853b9a1a	level_start	{"level": 8, "difficulty": "easy"}	2026-03-08 23:22:37.11005+03
333	100daaff-d23e-412c-b135-44eb853b9a1a	pause	{}	2026-03-08 23:37:54.37108+03
334	100daaff-d23e-412c-b135-44eb853b9a1a	checkpoint_reached	{"checkpoint": 1}	2026-03-08 23:36:44.084906+03
335	100daaff-d23e-412c-b135-44eb853b9a1a	powerup_used	{"powerup": "speed", "duration": 9}	2026-03-08 23:31:19.141805+03
336	100daaff-d23e-412c-b135-44eb853b9a1a	player_died	{"position": {"x": 88, "y": 20}, "enemy_nearby": false}	2026-03-08 23:38:57.010866+03
337	100daaff-d23e-412c-b135-44eb853b9a1a	checkpoint_reached	{"checkpoint": 1}	2026-03-08 23:13:24.95362+03
338	bbdec12a-90aa-41a4-8f43-a23bb151a48e	item_collected	{"item": "coin", "value": 19}	2026-02-17 00:04:09.357958+03
339	bbdec12a-90aa-41a4-8f43-a23bb151a48e	enemy_killed	{"position": {"x": 63, "y": 85}, "enemy_type": "goblin"}	2026-02-16 23:24:05.953306+03
340	bbdec12a-90aa-41a4-8f43-a23bb151a48e	item_collected	{"item": "gem", "value": 31}	2026-02-16 23:44:35.454447+03
341	bbdec12a-90aa-41a4-8f43-a23bb151a48e	level_start	{"level": 8, "difficulty": "hard"}	2026-02-16 23:20:11.962068+03
342	bbdec12a-90aa-41a4-8f43-a23bb151a48e	checkpoint_reached	{"checkpoint": 5}	2026-02-16 23:57:48.374606+03
343	bbdec12a-90aa-41a4-8f43-a23bb151a48e	pause	{}	2026-02-17 00:00:15.509838+03
344	bbdec12a-90aa-41a4-8f43-a23bb151a48e	level_start	{"level": 3, "difficulty": "easy"}	2026-02-16 23:48:06.171205+03
345	bbdec12a-90aa-41a4-8f43-a23bb151a48e	resume	{}	2026-02-17 00:06:54.1545+03
346	bbdec12a-90aa-41a4-8f43-a23bb151a48e	resume	{}	2026-02-16 23:59:35.877688+03
347	bbdec12a-90aa-41a4-8f43-a23bb151a48e	level_start	{"level": 5, "difficulty": "normal"}	2026-02-16 23:28:08.942282+03
348	bbdec12a-90aa-41a4-8f43-a23bb151a48e	pause	{}	2026-02-16 23:43:53.145578+03
349	bbdec12a-90aa-41a4-8f43-a23bb151a48e	level_end	{"level": 1, "score": 228, "success": false}	2026-02-16 23:48:21.992058+03
350	bbdec12a-90aa-41a4-8f43-a23bb151a48e	checkpoint_reached	{"checkpoint": 3}	2026-02-16 23:19:22.391694+03
351	bbdec12a-90aa-41a4-8f43-a23bb151a48e	enemy_killed	{"position": {"x": 28, "y": 86}, "enemy_type": "troll"}	2026-02-16 23:32:46.540536+03
352	bbdec12a-90aa-41a4-8f43-a23bb151a48e	enemy_killed	{"position": {"x": 37, "y": 99}, "enemy_type": "troll"}	2026-02-16 23:47:39.384671+03
353	bbdec12a-90aa-41a4-8f43-a23bb151a48e	enemy_killed	{"position": {"x": 94, "y": 6}, "enemy_type": "troll"}	2026-02-16 23:48:37.914294+03
354	bbdec12a-90aa-41a4-8f43-a23bb151a48e	level_start	{"level": 9, "difficulty": "normal"}	2026-02-16 23:29:22.925918+03
355	092539cc-204d-4bac-9f11-56f4926891e2	pause	{}	2026-03-12 07:11:40.787161+03
356	092539cc-204d-4bac-9f11-56f4926891e2	enemy_killed	{"position": {"x": 18, "y": 1}, "enemy_type": "goblin"}	2026-03-12 07:16:37.127482+03
357	092539cc-204d-4bac-9f11-56f4926891e2	checkpoint_reached	{"checkpoint": 5}	2026-03-12 06:32:53.133934+03
358	092539cc-204d-4bac-9f11-56f4926891e2	item_collected	{"item": "coin", "value": 48}	2026-03-12 06:40:10.553707+03
359	092539cc-204d-4bac-9f11-56f4926891e2	menu_open	{}	2026-03-12 07:06:22.530202+03
360	092539cc-204d-4bac-9f11-56f4926891e2	pause	{}	2026-03-12 06:27:28.796109+03
361	092539cc-204d-4bac-9f11-56f4926891e2	resume	{}	2026-03-12 06:53:29.407973+03
362	092539cc-204d-4bac-9f11-56f4926891e2	level_start	{"level": 5, "difficulty": "easy"}	2026-03-12 06:51:23.578939+03
363	092539cc-204d-4bac-9f11-56f4926891e2	level_start	{"level": 3, "difficulty": "easy"}	2026-03-12 07:22:31.985308+03
364	092539cc-204d-4bac-9f11-56f4926891e2	level_end	{"level": 10, "score": 632, "success": true}	2026-03-12 06:35:44.258099+03
365	092539cc-204d-4bac-9f11-56f4926891e2	powerup_used	{"powerup": "speed", "duration": 7}	2026-03-12 07:11:55.151899+03
366	092539cc-204d-4bac-9f11-56f4926891e2	enemy_killed	{"position": {"x": 19, "y": 65}, "enemy_type": "troll"}	2026-03-12 07:08:13.332596+03
367	092539cc-204d-4bac-9f11-56f4926891e2	enemy_killed	{"position": {"x": 83, "y": 44}, "enemy_type": "goblin"}	2026-03-12 06:27:47.865301+03
368	092539cc-204d-4bac-9f11-56f4926891e2	item_collected	{"item": "coin", "value": 1}	2026-03-12 07:11:08.781958+03
369	092539cc-204d-4bac-9f11-56f4926891e2	player_died	{"position": {"x": 5, "y": 8}, "enemy_nearby": true}	2026-03-12 07:01:55.937116+03
370	092539cc-204d-4bac-9f11-56f4926891e2	pause	{}	2026-03-12 07:03:09.399363+03
371	413a7c3e-813b-496d-8587-5698b6b471a5	enemy_killed	{"position": {"x": 84, "y": 25}, "enemy_type": "goblin"}	2026-02-26 14:17:35.143831+03
372	413a7c3e-813b-496d-8587-5698b6b471a5	enemy_killed	{"position": {"x": 94, "y": 45}, "enemy_type": "troll"}	2026-02-26 12:37:35.976498+03
373	413a7c3e-813b-496d-8587-5698b6b471a5	checkpoint_reached	{"checkpoint": 2}	2026-02-26 13:14:42.237837+03
374	413a7c3e-813b-496d-8587-5698b6b471a5	resume	{}	2026-02-26 13:03:23.512086+03
375	413a7c3e-813b-496d-8587-5698b6b471a5	checkpoint_reached	{"checkpoint": 3}	2026-02-26 11:24:32.919745+03
376	413a7c3e-813b-496d-8587-5698b6b471a5	level_end	{"level": 7, "score": 455, "success": true}	2026-02-26 11:52:23.852978+03
377	413a7c3e-813b-496d-8587-5698b6b471a5	item_collected	{"item": "key", "value": 13}	2026-02-26 13:40:37.070436+03
378	413a7c3e-813b-496d-8587-5698b6b471a5	level_start	{"level": 2, "difficulty": "normal"}	2026-02-26 10:53:29.633793+03
379	413a7c3e-813b-496d-8587-5698b6b471a5	powerup_used	{"powerup": "shield", "duration": 10}	2026-02-26 12:37:40.627563+03
380	413a7c3e-813b-496d-8587-5698b6b471a5	level_end	{"level": 9, "score": 770, "success": true}	2026-02-26 12:25:02.897783+03
381	413a7c3e-813b-496d-8587-5698b6b471a5	level_end	{"level": 5, "score": 415, "success": false}	2026-02-26 10:59:51.770074+03
382	413a7c3e-813b-496d-8587-5698b6b471a5	checkpoint_reached	{"checkpoint": 1}	2026-02-26 14:06:18.731637+03
383	413a7c3e-813b-496d-8587-5698b6b471a5	level_start	{"level": 7, "difficulty": "hard"}	2026-02-26 13:15:37.251697+03
384	413a7c3e-813b-496d-8587-5698b6b471a5	level_end	{"level": 6, "score": 940, "success": true}	2026-02-26 14:00:14.950351+03
385	413a7c3e-813b-496d-8587-5698b6b471a5	resume	{}	2026-02-26 13:16:24.258733+03
386	42513389-596d-44e9-ae82-c4d1734a4ab6	powerup_used	{"powerup": "shield", "duration": 11}	2026-03-08 22:07:48.956159+03
387	42513389-596d-44e9-ae82-c4d1734a4ab6	enemy_killed	{"position": {"x": 9, "y": 17}, "enemy_type": "goblin"}	2026-03-08 22:03:22.867534+03
388	42513389-596d-44e9-ae82-c4d1734a4ab6	enemy_killed	{"position": {"x": 79, "y": 76}, "enemy_type": "goblin"}	2026-03-08 22:04:29.608606+03
389	42513389-596d-44e9-ae82-c4d1734a4ab6	enemy_killed	{"position": {"x": 30, "y": 65}, "enemy_type": "troll"}	2026-03-08 21:49:00.514796+03
390	42513389-596d-44e9-ae82-c4d1734a4ab6	level_end	{"level": 3, "score": 655, "success": true}	2026-03-08 22:04:40.979152+03
391	09513d13-78d5-436a-a25e-ca8abdb5ad08	player_died	{"position": {"x": 54, "y": 21}, "enemy_nearby": false}	2026-03-09 08:36:53.125318+03
392	09513d13-78d5-436a-a25e-ca8abdb5ad08	menu_open	{}	2026-03-09 08:40:17.723611+03
393	09513d13-78d5-436a-a25e-ca8abdb5ad08	pause	{}	2026-03-09 08:46:54.535051+03
394	09513d13-78d5-436a-a25e-ca8abdb5ad08	level_start	{"level": 5, "difficulty": "easy"}	2026-03-09 08:34:03.037755+03
395	09513d13-78d5-436a-a25e-ca8abdb5ad08	checkpoint_reached	{"checkpoint": 2}	2026-03-09 08:42:10.107798+03
396	09513d13-78d5-436a-a25e-ca8abdb5ad08	enemy_killed	{"position": {"x": 90, "y": 36}, "enemy_type": "goblin"}	2026-03-09 08:45:18.73878+03
397	09513d13-78d5-436a-a25e-ca8abdb5ad08	checkpoint_reached	{"checkpoint": 5}	2026-03-09 08:39:44.202786+03
398	09513d13-78d5-436a-a25e-ca8abdb5ad08	powerup_used	{"powerup": "speed", "duration": 14}	2026-03-09 08:46:54.68987+03
399	09513d13-78d5-436a-a25e-ca8abdb5ad08	player_died	{"position": {"x": 0, "y": 79}, "enemy_nearby": true}	2026-03-09 08:36:17.921672+03
400	09513d13-78d5-436a-a25e-ca8abdb5ad08	menu_open	{}	2026-03-09 08:48:10.987149+03
401	09513d13-78d5-436a-a25e-ca8abdb5ad08	checkpoint_reached	{"checkpoint": 3}	2026-03-09 08:42:38.65513+03
402	09513d13-78d5-436a-a25e-ca8abdb5ad08	player_died	{"position": {"x": 83, "y": 18}, "enemy_nearby": true}	2026-03-09 08:48:05.051904+03
403	09513d13-78d5-436a-a25e-ca8abdb5ad08	item_collected	{"item": "gem", "value": 29}	2026-03-09 08:33:24.172126+03
404	09513d13-78d5-436a-a25e-ca8abdb5ad08	pause	{}	2026-03-09 08:39:11.761125+03
405	09513d13-78d5-436a-a25e-ca8abdb5ad08	resume	{}	2026-03-09 08:48:19.92347+03
406	09513d13-78d5-436a-a25e-ca8abdb5ad08	menu_open	{}	2026-03-09 08:40:18.390144+03
407	09513d13-78d5-436a-a25e-ca8abdb5ad08	level_start	{"level": 4, "difficulty": "normal"}	2026-03-09 08:35:14.362893+03
408	72ef4b97-f523-41ed-9d52-025d754a712a	item_collected	{"item": "gem", "value": 37}	2026-03-11 10:26:11.519773+03
409	72ef4b97-f523-41ed-9d52-025d754a712a	level_end	{"level": 5, "score": 409, "success": false}	2026-03-11 10:23:52.239908+03
410	72ef4b97-f523-41ed-9d52-025d754a712a	powerup_used	{"powerup": "shield", "duration": 10}	2026-03-11 10:26:56.127568+03
411	72ef4b97-f523-41ed-9d52-025d754a712a	level_start	{"level": 5, "difficulty": "normal"}	2026-03-11 10:26:48.103417+03
412	72ef4b97-f523-41ed-9d52-025d754a712a	resume	{}	2026-03-11 10:24:28.149817+03
413	72ef4b97-f523-41ed-9d52-025d754a712a	pause	{}	2026-03-11 10:24:30.611487+03
414	72ef4b97-f523-41ed-9d52-025d754a712a	menu_open	{}	2026-03-11 10:24:14.694398+03
415	72ef4b97-f523-41ed-9d52-025d754a712a	menu_open	{}	2026-03-11 10:23:29.71162+03
416	72ef4b97-f523-41ed-9d52-025d754a712a	player_died	{"position": {"x": 58, "y": 90}, "enemy_nearby": true}	2026-03-11 10:26:52.940706+03
417	72ef4b97-f523-41ed-9d52-025d754a712a	resume	{}	2026-03-11 10:25:22.611277+03
418	72ef4b97-f523-41ed-9d52-025d754a712a	resume	{}	2026-03-11 10:23:45.476145+03
419	72ef4b97-f523-41ed-9d52-025d754a712a	enemy_killed	{"position": {"x": 73, "y": 75}, "enemy_type": "troll"}	2026-03-11 10:23:12.649694+03
420	72ef4b97-f523-41ed-9d52-025d754a712a	enemy_killed	{"position": {"x": 91, "y": 39}, "enemy_type": "troll"}	2026-03-11 10:26:59.15161+03
421	72ef4b97-f523-41ed-9d52-025d754a712a	player_died	{"position": {"x": 36, "y": 61}, "enemy_nearby": true}	2026-03-11 10:23:16.850434+03
422	72ef4b97-f523-41ed-9d52-025d754a712a	resume	{}	2026-03-11 10:24:20.781758+03
423	72ef4b97-f523-41ed-9d52-025d754a712a	player_died	{"position": {"x": 55, "y": 97}, "enemy_nearby": false}	2026-03-11 10:24:56.259796+03
424	a1f0a834-127d-4362-8793-702b6448b0bc	checkpoint_reached	{"checkpoint": 3}	2026-02-19 01:57:05.769818+03
425	a1f0a834-127d-4362-8793-702b6448b0bc	level_start	{"level": 10, "difficulty": "normal"}	2026-02-19 02:06:59.357817+03
426	a1f0a834-127d-4362-8793-702b6448b0bc	pause	{}	2026-02-19 02:00:19.105555+03
427	a1f0a834-127d-4362-8793-702b6448b0bc	level_end	{"level": 2, "score": 874, "success": false}	2026-02-19 01:47:08.485747+03
428	a1f0a834-127d-4362-8793-702b6448b0bc	item_collected	{"item": "coin", "value": 45}	2026-02-19 01:55:49.705965+03
429	315936c8-08fe-40d3-a87c-3bbcd372f8c7	pause	{}	2026-03-11 15:45:49.300271+03
430	315936c8-08fe-40d3-a87c-3bbcd372f8c7	level_end	{"level": 6, "score": 87, "success": true}	2026-03-11 16:08:24.373177+03
431	315936c8-08fe-40d3-a87c-3bbcd372f8c7	level_end	{"level": 7, "score": 169, "success": false}	2026-03-11 15:48:50.702128+03
432	315936c8-08fe-40d3-a87c-3bbcd372f8c7	checkpoint_reached	{"checkpoint": 1}	2026-03-11 16:00:32.938738+03
433	315936c8-08fe-40d3-a87c-3bbcd372f8c7	resume	{}	2026-03-11 16:09:25.980071+03
434	315936c8-08fe-40d3-a87c-3bbcd372f8c7	player_died	{"position": {"x": 72, "y": 19}, "enemy_nearby": true}	2026-03-11 15:57:13.256431+03
435	315936c8-08fe-40d3-a87c-3bbcd372f8c7	player_died	{"position": {"x": 50, "y": 13}, "enemy_nearby": false}	2026-03-11 16:14:13.512344+03
436	315936c8-08fe-40d3-a87c-3bbcd372f8c7	enemy_killed	{"position": {"x": 18, "y": 3}, "enemy_type": "troll"}	2026-03-11 16:09:25.666329+03
437	315936c8-08fe-40d3-a87c-3bbcd372f8c7	level_end	{"level": 10, "score": 249, "success": true}	2026-03-11 16:04:45.481799+03
438	315936c8-08fe-40d3-a87c-3bbcd372f8c7	pause	{}	2026-03-11 16:15:30.102987+03
439	315936c8-08fe-40d3-a87c-3bbcd372f8c7	powerup_used	{"powerup": "shield", "duration": 5}	2026-03-11 16:07:23.970231+03
440	315936c8-08fe-40d3-a87c-3bbcd372f8c7	menu_open	{}	2026-03-11 15:47:16.928244+03
441	315936c8-08fe-40d3-a87c-3bbcd372f8c7	level_start	{"level": 7, "difficulty": "easy"}	2026-03-11 15:47:26.982969+03
442	315936c8-08fe-40d3-a87c-3bbcd372f8c7	menu_open	{}	2026-03-11 15:45:32.613814+03
443	315936c8-08fe-40d3-a87c-3bbcd372f8c7	item_collected	{"item": "gem", "value": 35}	2026-03-11 16:07:04.965627+03
444	315936c8-08fe-40d3-a87c-3bbcd372f8c7	menu_open	{}	2026-03-11 16:13:25.567674+03
445	315936c8-08fe-40d3-a87c-3bbcd372f8c7	resume	{}	2026-03-11 15:46:56.301849+03
446	315936c8-08fe-40d3-a87c-3bbcd372f8c7	item_collected	{"item": "gem", "value": 7}	2026-03-11 16:13:58.564538+03
447	315936c8-08fe-40d3-a87c-3bbcd372f8c7	item_collected	{"item": "gem", "value": 22}	2026-03-11 16:11:58.557269+03
448	e0aa7abf-fd5b-44da-90ad-10620810a67e	checkpoint_reached	{"checkpoint": 5}	2026-02-19 05:50:22.266115+03
449	e0aa7abf-fd5b-44da-90ad-10620810a67e	powerup_used	{"powerup": "speed", "duration": 11}	2026-02-19 05:54:18.233942+03
450	e0aa7abf-fd5b-44da-90ad-10620810a67e	pause	{}	2026-02-19 05:48:14.064859+03
451	e0aa7abf-fd5b-44da-90ad-10620810a67e	item_collected	{"item": "coin", "value": 28}	2026-02-19 05:55:05.403083+03
452	e0aa7abf-fd5b-44da-90ad-10620810a67e	item_collected	{"item": "gem", "value": 45}	2026-02-19 05:56:52.713045+03
453	e0aa7abf-fd5b-44da-90ad-10620810a67e	resume	{}	2026-02-19 05:58:09.73314+03
454	e0aa7abf-fd5b-44da-90ad-10620810a67e	menu_open	{}	2026-02-19 05:44:31.613387+03
455	e0aa7abf-fd5b-44da-90ad-10620810a67e	item_collected	{"item": "gem", "value": 9}	2026-02-19 05:57:17.371334+03
456	e0aa7abf-fd5b-44da-90ad-10620810a67e	enemy_killed	{"position": {"x": 23, "y": 1}, "enemy_type": "goblin"}	2026-02-19 05:51:39.178874+03
457	e0aa7abf-fd5b-44da-90ad-10620810a67e	enemy_killed	{"position": {"x": 84, "y": 98}, "enemy_type": "troll"}	2026-02-19 05:50:20.039214+03
458	e0aa7abf-fd5b-44da-90ad-10620810a67e	item_collected	{"item": "key", "value": 46}	2026-02-19 05:53:47.255515+03
459	e0aa7abf-fd5b-44da-90ad-10620810a67e	level_end	{"level": 4, "score": 71, "success": true}	2026-02-19 05:45:22.269561+03
460	e0aa7abf-fd5b-44da-90ad-10620810a67e	menu_open	{}	2026-02-19 05:53:51.393988+03
461	e020f5e8-8edb-4a9b-8958-2036dc805b2a	menu_open	{}	2026-03-08 04:56:13.545525+03
462	e020f5e8-8edb-4a9b-8958-2036dc805b2a	level_end	{"level": 1, "score": 14, "success": true}	2026-03-08 04:34:28.002638+03
463	e020f5e8-8edb-4a9b-8958-2036dc805b2a	enemy_killed	{"position": {"x": 12, "y": 18}, "enemy_type": "troll"}	2026-03-08 04:37:16.632857+03
464	e020f5e8-8edb-4a9b-8958-2036dc805b2a	pause	{}	2026-03-08 04:53:36.518156+03
465	e020f5e8-8edb-4a9b-8958-2036dc805b2a	item_collected	{"item": "gem", "value": 23}	2026-03-08 04:56:30.536893+03
466	e020f5e8-8edb-4a9b-8958-2036dc805b2a	checkpoint_reached	{"checkpoint": 5}	2026-03-08 04:55:58.222579+03
467	e020f5e8-8edb-4a9b-8958-2036dc805b2a	pause	{}	2026-03-08 04:30:02.704223+03
468	4417fcd8-656b-47b6-b7b9-d4ada88e2ab1	player_died	{"position": {"x": 73, "y": 96}, "enemy_nearby": true}	2026-02-24 05:43:53.908609+03
469	4417fcd8-656b-47b6-b7b9-d4ada88e2ab1	checkpoint_reached	{"checkpoint": 5}	2026-02-24 05:38:11.731804+03
470	4417fcd8-656b-47b6-b7b9-d4ada88e2ab1	powerup_used	{"powerup": "shield", "duration": 11}	2026-02-24 05:39:58.462312+03
471	4417fcd8-656b-47b6-b7b9-d4ada88e2ab1	pause	{}	2026-02-24 05:36:37.419163+03
472	4417fcd8-656b-47b6-b7b9-d4ada88e2ab1	pause	{}	2026-02-24 05:38:53.842664+03
473	4417fcd8-656b-47b6-b7b9-d4ada88e2ab1	item_collected	{"item": "coin", "value": 12}	2026-02-24 05:44:53.286936+03
474	4417fcd8-656b-47b6-b7b9-d4ada88e2ab1	item_collected	{"item": "key", "value": 26}	2026-02-24 05:44:39.862289+03
475	4417fcd8-656b-47b6-b7b9-d4ada88e2ab1	resume	{}	2026-02-24 05:35:49.851622+03
476	3d23b256-471c-4afa-ba12-4d3a9357fb45	item_collected	{"item": "key", "value": 14}	2026-03-06 21:37:03.194696+03
477	3d23b256-471c-4afa-ba12-4d3a9357fb45	level_start	{"level": 10, "difficulty": "normal"}	2026-03-06 21:53:26.488928+03
478	3d23b256-471c-4afa-ba12-4d3a9357fb45	resume	{}	2026-03-06 21:57:04.993037+03
479	3d23b256-471c-4afa-ba12-4d3a9357fb45	enemy_killed	{"position": {"x": 18, "y": 17}, "enemy_type": "goblin"}	2026-03-06 21:44:44.181222+03
480	3d23b256-471c-4afa-ba12-4d3a9357fb45	checkpoint_reached	{"checkpoint": 2}	2026-03-06 21:52:47.407336+03
481	3d23b256-471c-4afa-ba12-4d3a9357fb45	checkpoint_reached	{"checkpoint": 4}	2026-03-06 22:02:29.880941+03
482	3d23b256-471c-4afa-ba12-4d3a9357fb45	powerup_used	{"powerup": "speed", "duration": 13}	2026-03-06 22:08:43.105923+03
483	3d23b256-471c-4afa-ba12-4d3a9357fb45	enemy_killed	{"position": {"x": 45, "y": 68}, "enemy_type": "goblin"}	2026-03-06 21:54:34.76972+03
484	3d23b256-471c-4afa-ba12-4d3a9357fb45	enemy_killed	{"position": {"x": 21, "y": 50}, "enemy_type": "goblin"}	2026-03-06 21:38:10.291492+03
485	3d23b256-471c-4afa-ba12-4d3a9357fb45	powerup_used	{"powerup": "speed", "duration": 8}	2026-03-06 21:41:07.440144+03
486	3d23b256-471c-4afa-ba12-4d3a9357fb45	item_collected	{"item": "gem", "value": 35}	2026-03-06 22:09:11.336306+03
487	3d23b256-471c-4afa-ba12-4d3a9357fb45	powerup_used	{"powerup": "shield", "duration": 5}	2026-03-06 21:54:37.339168+03
488	3d23b256-471c-4afa-ba12-4d3a9357fb45	menu_open	{}	2026-03-06 21:41:34.479356+03
489	3d23b256-471c-4afa-ba12-4d3a9357fb45	player_died	{"position": {"x": 11, "y": 95}, "enemy_nearby": true}	2026-03-06 22:06:49.463479+03
490	3d23b256-471c-4afa-ba12-4d3a9357fb45	player_died	{"position": {"x": 1, "y": 17}, "enemy_nearby": false}	2026-03-06 21:39:10.369343+03
491	3d23b256-471c-4afa-ba12-4d3a9357fb45	resume	{}	2026-03-06 21:43:00.600704+03
492	3d23b256-471c-4afa-ba12-4d3a9357fb45	powerup_used	{"powerup": "speed", "duration": 8}	2026-03-06 22:07:22.162353+03
493	3d23b256-471c-4afa-ba12-4d3a9357fb45	pause	{}	2026-03-06 22:03:53.496612+03
494	1175f786-f0c0-484b-bc70-b0475448eae3	powerup_used	{"powerup": "speed", "duration": 5}	2026-03-06 17:28:15.358573+03
495	1175f786-f0c0-484b-bc70-b0475448eae3	checkpoint_reached	{"checkpoint": 2}	2026-03-06 16:21:16.948399+03
496	1175f786-f0c0-484b-bc70-b0475448eae3	player_died	{"position": {"x": 70, "y": 5}, "enemy_nearby": false}	2026-03-06 16:01:24.662191+03
497	1175f786-f0c0-484b-bc70-b0475448eae3	level_start	{"level": 1, "difficulty": "easy"}	2026-03-06 17:06:48.692678+03
498	1175f786-f0c0-484b-bc70-b0475448eae3	item_collected	{"item": "gem", "value": 19}	2026-03-06 16:03:48.364391+03
499	1175f786-f0c0-484b-bc70-b0475448eae3	enemy_killed	{"position": {"x": 23, "y": 16}, "enemy_type": "troll"}	2026-03-06 16:45:04.8917+03
500	1175f786-f0c0-484b-bc70-b0475448eae3	powerup_used	{"powerup": "speed", "duration": 5}	2026-03-06 16:52:29.107878+03
501	1175f786-f0c0-484b-bc70-b0475448eae3	item_collected	{"item": "gem", "value": 47}	2026-03-06 17:59:39.430841+03
502	1175f786-f0c0-484b-bc70-b0475448eae3	resume	{}	2026-03-06 17:35:34.014674+03
503	1175f786-f0c0-484b-bc70-b0475448eae3	powerup_used	{"powerup": "speed", "duration": 8}	2026-03-06 16:53:44.476818+03
504	1175f786-f0c0-484b-bc70-b0475448eae3	enemy_killed	{"position": {"x": 27, "y": 99}, "enemy_type": "troll"}	2026-03-06 17:31:00.261888+03
505	1175f786-f0c0-484b-bc70-b0475448eae3	level_start	{"level": 5, "difficulty": "normal"}	2026-03-06 17:42:06.790298+03
506	1175f786-f0c0-484b-bc70-b0475448eae3	resume	{}	2026-03-06 18:23:36.241412+03
507	1175f786-f0c0-484b-bc70-b0475448eae3	powerup_used	{"powerup": "shield", "duration": 9}	2026-03-06 16:28:05.362278+03
508	1175f786-f0c0-484b-bc70-b0475448eae3	resume	{}	2026-03-06 17:46:41.114282+03
509	1175f786-f0c0-484b-bc70-b0475448eae3	enemy_killed	{"position": {"x": 48, "y": 83}, "enemy_type": "troll"}	2026-03-06 16:29:25.41449+03
510	95437a5d-b0ae-4de1-89cb-de3b11281899	level_end	{"level": 7, "score": 785, "success": true}	2026-02-15 06:44:49.778002+03
511	95437a5d-b0ae-4de1-89cb-de3b11281899	item_collected	{"item": "coin", "value": 38}	2026-02-15 06:50:33.473235+03
512	95437a5d-b0ae-4de1-89cb-de3b11281899	pause	{}	2026-02-15 06:52:40.435396+03
513	95437a5d-b0ae-4de1-89cb-de3b11281899	item_collected	{"item": "coin", "value": 13}	2026-02-15 06:54:24.534919+03
514	95437a5d-b0ae-4de1-89cb-de3b11281899	level_end	{"level": 7, "score": 811, "success": true}	2026-02-15 06:27:04.238202+03
515	95437a5d-b0ae-4de1-89cb-de3b11281899	enemy_killed	{"position": {"x": 6, "y": 69}, "enemy_type": "goblin"}	2026-02-15 06:30:48.888401+03
516	95437a5d-b0ae-4de1-89cb-de3b11281899	pause	{}	2026-02-15 06:39:05.933816+03
517	95437a5d-b0ae-4de1-89cb-de3b11281899	pause	{}	2026-02-15 06:52:12.03235+03
518	95437a5d-b0ae-4de1-89cb-de3b11281899	enemy_killed	{"position": {"x": 5, "y": 90}, "enemy_type": "goblin"}	2026-02-15 06:23:21.626841+03
519	95437a5d-b0ae-4de1-89cb-de3b11281899	menu_open	{}	2026-02-15 06:17:29.705687+03
520	95437a5d-b0ae-4de1-89cb-de3b11281899	player_died	{"position": {"x": 74, "y": 4}, "enemy_nearby": true}	2026-02-15 06:24:14.061598+03
521	95437a5d-b0ae-4de1-89cb-de3b11281899	menu_open	{}	2026-02-15 06:50:55.414714+03
522	95437a5d-b0ae-4de1-89cb-de3b11281899	pause	{}	2026-02-15 06:30:38.136937+03
523	0fb0688b-52b1-4740-9899-c24cdac441c7	item_collected	{"item": "gem", "value": 20}	2026-02-19 22:23:28.00536+03
524	0fb0688b-52b1-4740-9899-c24cdac441c7	level_end	{"level": 9, "score": 916, "success": true}	2026-02-19 22:20:51.989524+03
525	0fb0688b-52b1-4740-9899-c24cdac441c7	enemy_killed	{"position": {"x": 97, "y": 75}, "enemy_type": "troll"}	2026-02-19 22:17:13.091995+03
526	0fb0688b-52b1-4740-9899-c24cdac441c7	level_start	{"level": 8, "difficulty": "easy"}	2026-02-19 22:04:22.745874+03
527	0fb0688b-52b1-4740-9899-c24cdac441c7	powerup_used	{"powerup": "speed", "duration": 11}	2026-02-19 22:39:34.451375+03
528	0fb0688b-52b1-4740-9899-c24cdac441c7	resume	{}	2026-02-19 22:12:57.19228+03
529	0fb0688b-52b1-4740-9899-c24cdac441c7	player_died	{"position": {"x": 35, "y": 26}, "enemy_nearby": false}	2026-02-19 22:15:30.742042+03
530	0fb0688b-52b1-4740-9899-c24cdac441c7	level_start	{"level": 1, "difficulty": "normal"}	2026-02-19 22:38:08.875046+03
531	d0bb2bcc-f3eb-4837-a708-eb884826d2fb	level_start	{"level": 3, "difficulty": "normal"}	2026-03-14 03:08:00.249297+03
532	d0bb2bcc-f3eb-4837-a708-eb884826d2fb	resume	{}	2026-03-14 03:12:38.263636+03
533	d0bb2bcc-f3eb-4837-a708-eb884826d2fb	menu_open	{}	2026-03-14 03:11:12.120764+03
534	d0bb2bcc-f3eb-4837-a708-eb884826d2fb	level_end	{"level": 8, "score": 834, "success": true}	2026-03-14 03:08:34.663145+03
535	d0bb2bcc-f3eb-4837-a708-eb884826d2fb	level_end	{"level": 3, "score": 567, "success": false}	2026-03-14 03:25:23.565026+03
536	d0bb2bcc-f3eb-4837-a708-eb884826d2fb	menu_open	{}	2026-03-14 03:12:54.689403+03
537	d0bb2bcc-f3eb-4837-a708-eb884826d2fb	checkpoint_reached	{"checkpoint": 4}	2026-03-14 03:11:58.658673+03
538	335853f3-5eec-4031-b940-28ff6d0c0e6b	level_end	{"level": 7, "score": 374, "success": false}	2026-03-16 00:57:41.929525+03
539	335853f3-5eec-4031-b940-28ff6d0c0e6b	pause	{}	2026-03-16 01:24:39.76369+03
540	335853f3-5eec-4031-b940-28ff6d0c0e6b	checkpoint_reached	{"checkpoint": 5}	2026-03-16 00:39:36.482766+03
541	335853f3-5eec-4031-b940-28ff6d0c0e6b	level_end	{"level": 1, "score": 589, "success": true}	2026-03-16 01:23:32.300786+03
542	335853f3-5eec-4031-b940-28ff6d0c0e6b	menu_open	{}	2026-03-16 00:58:17.914256+03
543	335853f3-5eec-4031-b940-28ff6d0c0e6b	enemy_killed	{"position": {"x": 29, "y": 79}, "enemy_type": "goblin"}	2026-03-16 01:19:32.934057+03
544	335853f3-5eec-4031-b940-28ff6d0c0e6b	powerup_used	{"powerup": "shield", "duration": 10}	2026-03-16 00:57:47.998863+03
545	335853f3-5eec-4031-b940-28ff6d0c0e6b	enemy_killed	{"position": {"x": 0, "y": 38}, "enemy_type": "troll"}	2026-03-16 00:33:32.318877+03
546	335853f3-5eec-4031-b940-28ff6d0c0e6b	menu_open	{}	2026-03-16 00:48:25.782477+03
547	335853f3-5eec-4031-b940-28ff6d0c0e6b	level_start	{"level": 9, "difficulty": "easy"}	2026-03-16 01:06:52.055655+03
548	335853f3-5eec-4031-b940-28ff6d0c0e6b	level_start	{"level": 5, "difficulty": "normal"}	2026-03-16 00:58:36.513151+03
686	9880da5f-a1fe-4427-ab2d-745853339acd	item_collected	{"item": "gem", "value": 6}	2026-03-09 23:34:16.577143+03
549	9168908f-37ed-4522-ada0-e7c5642bb29b	enemy_killed	{"position": {"x": 93, "y": 40}, "enemy_type": "troll"}	2026-02-18 14:55:58.009447+03
550	9168908f-37ed-4522-ada0-e7c5642bb29b	item_collected	{"item": "gem", "value": 16}	2026-02-18 14:52:24.244371+03
551	9168908f-37ed-4522-ada0-e7c5642bb29b	checkpoint_reached	{"checkpoint": 1}	2026-02-18 14:57:02.839303+03
552	9168908f-37ed-4522-ada0-e7c5642bb29b	enemy_killed	{"position": {"x": 46, "y": 44}, "enemy_type": "goblin"}	2026-02-18 14:40:08.731949+03
553	9168908f-37ed-4522-ada0-e7c5642bb29b	player_died	{"position": {"x": 77, "y": 13}, "enemy_nearby": false}	2026-02-18 15:07:49.842838+03
554	9168908f-37ed-4522-ada0-e7c5642bb29b	resume	{}	2026-02-18 14:53:57.787595+03
555	9168908f-37ed-4522-ada0-e7c5642bb29b	level_end	{"level": 6, "score": 129, "success": true}	2026-02-18 14:45:59.511137+03
556	9168908f-37ed-4522-ada0-e7c5642bb29b	item_collected	{"item": "coin", "value": 44}	2026-02-18 14:32:42.593618+03
557	9168908f-37ed-4522-ada0-e7c5642bb29b	checkpoint_reached	{"checkpoint": 1}	2026-02-18 14:33:38.744186+03
558	9168908f-37ed-4522-ada0-e7c5642bb29b	powerup_used	{"powerup": "shield", "duration": 8}	2026-02-18 14:36:02.845848+03
559	9168908f-37ed-4522-ada0-e7c5642bb29b	level_end	{"level": 2, "score": 670, "success": false}	2026-02-18 14:31:04.413287+03
560	9168908f-37ed-4522-ada0-e7c5642bb29b	resume	{}	2026-02-18 14:37:09.271373+03
561	9168908f-37ed-4522-ada0-e7c5642bb29b	level_start	{"level": 3, "difficulty": "easy"}	2026-02-18 14:51:45.457812+03
562	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	checkpoint_reached	{"checkpoint": 5}	2026-03-12 03:25:14.481109+03
563	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	level_end	{"level": 5, "score": 691, "success": true}	2026-03-12 03:39:47.329418+03
564	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	menu_open	{}	2026-03-12 03:42:20.295411+03
565	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	player_died	{"position": {"x": 59, "y": 49}, "enemy_nearby": false}	2026-03-12 03:49:18.264588+03
566	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	player_died	{"position": {"x": 54, "y": 82}, "enemy_nearby": true}	2026-03-12 03:30:40.863328+03
567	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	menu_open	{}	2026-03-12 03:29:53.729144+03
568	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	level_start	{"level": 1, "difficulty": "hard"}	2026-03-12 03:38:14.981953+03
569	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	level_start	{"level": 6, "difficulty": "hard"}	2026-03-12 03:43:52.137739+03
570	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	enemy_killed	{"position": {"x": 20, "y": 12}, "enemy_type": "goblin"}	2026-03-12 03:26:25.180833+03
571	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	enemy_killed	{"position": {"x": 25, "y": 27}, "enemy_type": "goblin"}	2026-03-12 03:26:07.599025+03
572	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	resume	{}	2026-03-12 03:41:10.129793+03
573	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	player_died	{"position": {"x": 70, "y": 24}, "enemy_nearby": true}	2026-03-12 03:28:44.798896+03
574	8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	item_collected	{"item": "gem", "value": 27}	2026-03-12 03:35:49.894576+03
575	ae0161eb-0665-48c5-907c-bf763b9983b8	item_collected	{"item": "key", "value": 42}	2026-02-16 00:31:53.962225+03
576	ae0161eb-0665-48c5-907c-bf763b9983b8	item_collected	{"item": "key", "value": 35}	2026-02-16 00:20:07.149466+03
577	ae0161eb-0665-48c5-907c-bf763b9983b8	checkpoint_reached	{"checkpoint": 3}	2026-02-16 00:11:22.9165+03
578	ae0161eb-0665-48c5-907c-bf763b9983b8	powerup_used	{"powerup": "shield", "duration": 6}	2026-02-16 00:22:05.373587+03
579	ae0161eb-0665-48c5-907c-bf763b9983b8	checkpoint_reached	{"checkpoint": 2}	2026-02-16 00:08:16.040324+03
580	ae0161eb-0665-48c5-907c-bf763b9983b8	level_end	{"level": 10, "score": 94, "success": true}	2026-02-16 00:13:49.207997+03
581	ae0161eb-0665-48c5-907c-bf763b9983b8	item_collected	{"item": "gem", "value": 39}	2026-02-16 00:07:50.536097+03
582	ae0161eb-0665-48c5-907c-bf763b9983b8	powerup_used	{"powerup": "shield", "duration": 11}	2026-02-16 00:33:43.376841+03
583	ae0161eb-0665-48c5-907c-bf763b9983b8	enemy_killed	{"position": {"x": 46, "y": 32}, "enemy_type": "troll"}	2026-02-16 00:05:08.60264+03
584	ae0161eb-0665-48c5-907c-bf763b9983b8	powerup_used	{"powerup": "shield", "duration": 6}	2026-02-16 00:25:39.727268+03
585	4dcf3546-438d-4414-afce-5d62bb078009	player_died	{"position": {"x": 36, "y": 92}, "enemy_nearby": false}	2026-03-05 16:25:20.430631+03
586	4dcf3546-438d-4414-afce-5d62bb078009	item_collected	{"item": "coin", "value": 1}	2026-03-05 16:31:23.079075+03
587	4dcf3546-438d-4414-afce-5d62bb078009	level_end	{"level": 9, "score": 277, "success": true}	2026-03-05 16:25:13.838261+03
588	4dcf3546-438d-4414-afce-5d62bb078009	checkpoint_reached	{"checkpoint": 5}	2026-03-05 16:30:52.199702+03
589	4dcf3546-438d-4414-afce-5d62bb078009	level_start	{"level": 8, "difficulty": "hard"}	2026-03-05 16:31:16.17732+03
590	4dcf3546-438d-4414-afce-5d62bb078009	level_end	{"level": 6, "score": 680, "success": true}	2026-03-05 16:15:33.15556+03
591	4dcf3546-438d-4414-afce-5d62bb078009	item_collected	{"item": "gem", "value": 12}	2026-03-05 16:32:56.018344+03
592	4dcf3546-438d-4414-afce-5d62bb078009	enemy_killed	{"position": {"x": 79, "y": 95}, "enemy_type": "goblin"}	2026-03-05 16:28:42.073267+03
593	4dcf3546-438d-4414-afce-5d62bb078009	checkpoint_reached	{"checkpoint": 2}	2026-03-05 16:23:40.822623+03
594	4dcf3546-438d-4414-afce-5d62bb078009	menu_open	{}	2026-03-05 16:24:57.649815+03
595	4dcf3546-438d-4414-afce-5d62bb078009	level_end	{"level": 6, "score": 535, "success": true}	2026-03-05 16:33:22.81567+03
596	4dcf3546-438d-4414-afce-5d62bb078009	menu_open	{}	2026-03-05 16:17:27.345095+03
597	4dcf3546-438d-4414-afce-5d62bb078009	player_died	{"position": {"x": 35, "y": 25}, "enemy_nearby": true}	2026-03-05 16:28:55.964688+03
598	4dcf3546-438d-4414-afce-5d62bb078009	player_died	{"position": {"x": 40, "y": 79}, "enemy_nearby": false}	2026-03-05 16:26:15.604405+03
599	4dcf3546-438d-4414-afce-5d62bb078009	level_end	{"level": 8, "score": 819, "success": true}	2026-03-05 16:18:55.455276+03
600	4dcf3546-438d-4414-afce-5d62bb078009	player_died	{"position": {"x": 22, "y": 63}, "enemy_nearby": false}	2026-03-05 16:18:19.685934+03
601	4dcf3546-438d-4414-afce-5d62bb078009	enemy_killed	{"position": {"x": 65, "y": 33}, "enemy_type": "troll"}	2026-03-05 16:31:39.503382+03
602	4dcf3546-438d-4414-afce-5d62bb078009	menu_open	{}	2026-03-05 16:22:59.455336+03
603	4dcf3546-438d-4414-afce-5d62bb078009	level_start	{"level": 8, "difficulty": "easy"}	2026-03-05 16:19:36.998102+03
604	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	checkpoint_reached	{"checkpoint": 2}	2026-02-15 05:32:46.829626+03
605	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	item_collected	{"item": "gem", "value": 49}	2026-02-15 05:29:52.593315+03
606	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	powerup_used	{"powerup": "speed", "duration": 8}	2026-02-15 05:51:48.750345+03
607	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	pause	{}	2026-02-15 06:01:54.807231+03
608	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	powerup_used	{"powerup": "speed", "duration": 11}	2026-02-15 05:34:55.245945+03
609	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	resume	{}	2026-02-15 05:22:57.315847+03
610	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	player_died	{"position": {"x": 95, "y": 90}, "enemy_nearby": true}	2026-02-15 06:05:36.235289+03
611	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	item_collected	{"item": "gem", "value": 15}	2026-02-15 05:50:46.394041+03
612	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	item_collected	{"item": "key", "value": 9}	2026-02-15 05:38:48.143509+03
613	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	player_died	{"position": {"x": 92, "y": 57}, "enemy_nearby": false}	2026-02-15 06:05:41.312984+03
614	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	player_died	{"position": {"x": 85, "y": 60}, "enemy_nearby": true}	2026-02-15 06:10:52.250262+03
615	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	level_start	{"level": 1, "difficulty": "normal"}	2026-02-15 06:03:36.663898+03
616	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	enemy_killed	{"position": {"x": 85, "y": 14}, "enemy_type": "goblin"}	2026-02-15 05:24:24.752329+03
617	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	checkpoint_reached	{"checkpoint": 5}	2026-02-15 05:50:10.424258+03
618	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	menu_open	{}	2026-02-15 05:39:31.403272+03
619	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	enemy_killed	{"position": {"x": 95, "y": 44}, "enemy_type": "goblin"}	2026-02-15 05:33:37.85139+03
620	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	item_collected	{"item": "gem", "value": 30}	2026-02-15 05:38:16.884453+03
621	54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	item_collected	{"item": "coin", "value": 0}	2026-02-15 05:39:22.655516+03
622	0895303e-8bb6-4cab-9156-ba03a996fd25	enemy_killed	{"position": {"x": 3, "y": 80}, "enemy_type": "troll"}	2026-02-28 23:31:59.17154+03
623	0895303e-8bb6-4cab-9156-ba03a996fd25	checkpoint_reached	{"checkpoint": 1}	2026-03-01 02:17:11.355216+03
624	0895303e-8bb6-4cab-9156-ba03a996fd25	checkpoint_reached	{"checkpoint": 1}	2026-03-01 01:03:17.459664+03
625	0895303e-8bb6-4cab-9156-ba03a996fd25	item_collected	{"item": "coin", "value": 39}	2026-02-28 23:20:20.844478+03
626	0895303e-8bb6-4cab-9156-ba03a996fd25	enemy_killed	{"position": {"x": 39, "y": 26}, "enemy_type": "goblin"}	2026-03-01 01:41:10.110601+03
627	0895303e-8bb6-4cab-9156-ba03a996fd25	menu_open	{}	2026-03-01 01:20:08.295342+03
628	0895303e-8bb6-4cab-9156-ba03a996fd25	enemy_killed	{"position": {"x": 89, "y": 5}, "enemy_type": "goblin"}	2026-03-01 02:05:06.444031+03
629	0895303e-8bb6-4cab-9156-ba03a996fd25	item_collected	{"item": "coin", "value": 13}	2026-03-01 00:14:18.280872+03
630	0895303e-8bb6-4cab-9156-ba03a996fd25	resume	{}	2026-03-01 01:24:06.357016+03
631	0895303e-8bb6-4cab-9156-ba03a996fd25	resume	{}	2026-03-01 02:00:09.73093+03
632	0895303e-8bb6-4cab-9156-ba03a996fd25	resume	{}	2026-03-01 00:46:21.869705+03
633	0895303e-8bb6-4cab-9156-ba03a996fd25	item_collected	{"item": "coin", "value": 18}	2026-03-01 00:55:05.153571+03
634	334cc212-8138-462c-b1ef-0fee08d08a05	checkpoint_reached	{"checkpoint": 4}	2026-02-19 23:17:38.272493+03
635	334cc212-8138-462c-b1ef-0fee08d08a05	resume	{}	2026-02-19 23:06:40.206029+03
636	334cc212-8138-462c-b1ef-0fee08d08a05	resume	{}	2026-02-19 23:11:38.295165+03
637	334cc212-8138-462c-b1ef-0fee08d08a05	checkpoint_reached	{"checkpoint": 1}	2026-02-19 23:02:49.569217+03
638	334cc212-8138-462c-b1ef-0fee08d08a05	resume	{}	2026-02-19 23:11:51.493106+03
639	334cc212-8138-462c-b1ef-0fee08d08a05	level_start	{"level": 6, "difficulty": "hard"}	2026-02-19 23:07:47.203913+03
640	334cc212-8138-462c-b1ef-0fee08d08a05	resume	{}	2026-02-19 23:20:06.769396+03
641	334cc212-8138-462c-b1ef-0fee08d08a05	item_collected	{"item": "gem", "value": 26}	2026-02-19 23:18:59.551173+03
642	334cc212-8138-462c-b1ef-0fee08d08a05	pause	{}	2026-02-19 23:12:32.621291+03
643	334cc212-8138-462c-b1ef-0fee08d08a05	resume	{}	2026-02-19 23:16:06.287726+03
644	334cc212-8138-462c-b1ef-0fee08d08a05	pause	{}	2026-02-19 22:53:04.588683+03
645	334cc212-8138-462c-b1ef-0fee08d08a05	powerup_used	{"powerup": "speed", "duration": 7}	2026-02-19 23:23:37.189046+03
646	334cc212-8138-462c-b1ef-0fee08d08a05	pause	{}	2026-02-19 22:48:43.359409+03
647	334cc212-8138-462c-b1ef-0fee08d08a05	level_end	{"level": 8, "score": 796, "success": true}	2026-02-19 23:09:28.651403+03
648	334cc212-8138-462c-b1ef-0fee08d08a05	powerup_used	{"powerup": "shield", "duration": 13}	2026-02-19 23:05:48.504665+03
649	334cc212-8138-462c-b1ef-0fee08d08a05	powerup_used	{"powerup": "speed", "duration": 6}	2026-02-19 22:49:17.986624+03
650	b00e3f58-6c36-44da-8942-a007e9ab163a	menu_open	{}	2026-03-09 21:35:39.536939+03
651	b00e3f58-6c36-44da-8942-a007e9ab163a	level_end	{"level": 3, "score": 942, "success": true}	2026-03-09 19:17:18.051316+03
652	b00e3f58-6c36-44da-8942-a007e9ab163a	powerup_used	{"powerup": "speed", "duration": 10}	2026-03-09 19:18:45.516252+03
653	b00e3f58-6c36-44da-8942-a007e9ab163a	menu_open	{}	2026-03-09 20:16:28.370764+03
654	b00e3f58-6c36-44da-8942-a007e9ab163a	menu_open	{}	2026-03-09 18:59:22.87568+03
655	b00e3f58-6c36-44da-8942-a007e9ab163a	level_start	{"level": 8, "difficulty": "easy"}	2026-03-09 21:02:36.290212+03
656	b00e3f58-6c36-44da-8942-a007e9ab163a	item_collected	{"item": "key", "value": 1}	2026-03-09 19:11:45.836823+03
657	b00e3f58-6c36-44da-8942-a007e9ab163a	menu_open	{}	2026-03-09 19:09:39.976345+03
658	b00e3f58-6c36-44da-8942-a007e9ab163a	resume	{}	2026-03-09 19:59:15.706604+03
659	b00e3f58-6c36-44da-8942-a007e9ab163a	pause	{}	2026-03-09 21:43:25.167444+03
660	b00e3f58-6c36-44da-8942-a007e9ab163a	resume	{}	2026-03-09 20:38:06.957678+03
661	b00e3f58-6c36-44da-8942-a007e9ab163a	menu_open	{}	2026-03-09 20:40:58.171627+03
662	b00e3f58-6c36-44da-8942-a007e9ab163a	level_start	{"level": 6, "difficulty": "normal"}	2026-03-09 21:17:19.963921+03
663	b00e3f58-6c36-44da-8942-a007e9ab163a	checkpoint_reached	{"checkpoint": 5}	2026-03-09 19:48:54.729522+03
664	b6deebbc-330b-4c95-9cb5-91de68dd983f	resume	{}	2026-03-16 06:47:02.540764+03
665	b6deebbc-330b-4c95-9cb5-91de68dd983f	player_died	{"position": {"x": 52, "y": 91}, "enemy_nearby": false}	2026-03-16 06:45:19.673991+03
666	b6deebbc-330b-4c95-9cb5-91de68dd983f	enemy_killed	{"position": {"x": 42, "y": 59}, "enemy_type": "goblin"}	2026-03-16 06:46:16.208945+03
667	b6deebbc-330b-4c95-9cb5-91de68dd983f	enemy_killed	{"position": {"x": 85, "y": 88}, "enemy_type": "goblin"}	2026-03-16 06:46:14.336677+03
668	b6deebbc-330b-4c95-9cb5-91de68dd983f	checkpoint_reached	{"checkpoint": 3}	2026-03-16 06:45:48.74279+03
669	b6deebbc-330b-4c95-9cb5-91de68dd983f	powerup_used	{"powerup": "speed", "duration": 12}	2026-03-16 06:48:26.499952+03
670	b6deebbc-330b-4c95-9cb5-91de68dd983f	menu_open	{}	2026-03-16 06:45:12.018722+03
671	b6deebbc-330b-4c95-9cb5-91de68dd983f	menu_open	{}	2026-03-16 06:48:39.475025+03
672	b6deebbc-330b-4c95-9cb5-91de68dd983f	level_start	{"level": 6, "difficulty": "normal"}	2026-03-16 06:47:59.244983+03
673	b6deebbc-330b-4c95-9cb5-91de68dd983f	item_collected	{"item": "gem", "value": 7}	2026-03-16 06:45:56.615917+03
674	b6deebbc-330b-4c95-9cb5-91de68dd983f	pause	{}	2026-03-16 06:46:38.597065+03
675	b6deebbc-330b-4c95-9cb5-91de68dd983f	level_start	{"level": 5, "difficulty": "easy"}	2026-03-16 06:48:08.137112+03
676	b6deebbc-330b-4c95-9cb5-91de68dd983f	resume	{}	2026-03-16 06:48:41.202426+03
677	b6deebbc-330b-4c95-9cb5-91de68dd983f	level_end	{"level": 5, "score": 306, "success": false}	2026-03-16 06:45:11.451789+03
678	9880da5f-a1fe-4427-ab2d-745853339acd	enemy_killed	{"position": {"x": 8, "y": 53}, "enemy_type": "goblin"}	2026-03-09 23:51:06.070004+03
679	9880da5f-a1fe-4427-ab2d-745853339acd	pause	{}	2026-03-10 00:06:53.649623+03
680	9880da5f-a1fe-4427-ab2d-745853339acd	checkpoint_reached	{"checkpoint": 3}	2026-03-09 23:49:40.746976+03
681	9880da5f-a1fe-4427-ab2d-745853339acd	resume	{}	2026-03-10 00:01:52.673679+03
682	9880da5f-a1fe-4427-ab2d-745853339acd	enemy_killed	{"position": {"x": 78, "y": 65}, "enemy_type": "goblin"}	2026-03-09 23:59:49.060826+03
683	9880da5f-a1fe-4427-ab2d-745853339acd	item_collected	{"item": "gem", "value": 26}	2026-03-10 00:06:59.359911+03
684	9880da5f-a1fe-4427-ab2d-745853339acd	checkpoint_reached	{"checkpoint": 5}	2026-03-09 23:57:24.897351+03
685	9880da5f-a1fe-4427-ab2d-745853339acd	menu_open	{}	2026-03-09 23:37:22.646849+03
687	9880da5f-a1fe-4427-ab2d-745853339acd	item_collected	{"item": "gem", "value": 39}	2026-03-09 23:45:12.821711+03
688	9880da5f-a1fe-4427-ab2d-745853339acd	level_start	{"level": 5, "difficulty": "normal"}	2026-03-09 23:58:41.362243+03
689	9880da5f-a1fe-4427-ab2d-745853339acd	item_collected	{"item": "gem", "value": 48}	2026-03-10 00:02:25.546285+03
690	9880da5f-a1fe-4427-ab2d-745853339acd	level_start	{"level": 9, "difficulty": "normal"}	2026-03-09 23:36:39.365444+03
691	9880da5f-a1fe-4427-ab2d-745853339acd	checkpoint_reached	{"checkpoint": 4}	2026-03-09 23:42:16.180696+03
692	9880da5f-a1fe-4427-ab2d-745853339acd	enemy_killed	{"position": {"x": 28, "y": 0}, "enemy_type": "goblin"}	2026-03-09 23:28:31.381434+03
693	9880da5f-a1fe-4427-ab2d-745853339acd	enemy_killed	{"position": {"x": 12, "y": 74}, "enemy_type": "goblin"}	2026-03-09 23:47:29.785525+03
694	9880da5f-a1fe-4427-ab2d-745853339acd	item_collected	{"item": "gem", "value": 33}	2026-03-09 23:28:02.558951+03
695	9880da5f-a1fe-4427-ab2d-745853339acd	player_died	{"position": {"x": 83, "y": 33}, "enemy_nearby": true}	2026-03-09 23:46:55.391007+03
696	9880da5f-a1fe-4427-ab2d-745853339acd	enemy_killed	{"position": {"x": 90, "y": 87}, "enemy_type": "troll"}	2026-03-10 00:05:53.830986+03
697	9880da5f-a1fe-4427-ab2d-745853339acd	checkpoint_reached	{"checkpoint": 2}	2026-03-10 00:03:00.352827+03
698	f98044f3-8ac9-4219-a06b-097e230667e7	resume	{}	2026-03-07 18:52:56.157441+03
699	f98044f3-8ac9-4219-a06b-097e230667e7	pause	{}	2026-03-07 19:00:42.358874+03
700	f98044f3-8ac9-4219-a06b-097e230667e7	resume	{}	2026-03-07 18:41:51.088937+03
701	f98044f3-8ac9-4219-a06b-097e230667e7	pause	{}	2026-03-07 19:11:44.852319+03
702	f98044f3-8ac9-4219-a06b-097e230667e7	level_end	{"level": 2, "score": 319, "success": true}	2026-03-07 18:42:18.122721+03
703	f98044f3-8ac9-4219-a06b-097e230667e7	checkpoint_reached	{"checkpoint": 3}	2026-03-07 18:39:56.066339+03
704	f98044f3-8ac9-4219-a06b-097e230667e7	menu_open	{}	2026-03-07 19:13:35.441527+03
705	f98044f3-8ac9-4219-a06b-097e230667e7	checkpoint_reached	{"checkpoint": 4}	2026-03-07 19:03:54.757178+03
706	f98044f3-8ac9-4219-a06b-097e230667e7	player_died	{"position": {"x": 36, "y": 54}, "enemy_nearby": false}	2026-03-07 18:58:51.310665+03
707	f98044f3-8ac9-4219-a06b-097e230667e7	level_start	{"level": 9, "difficulty": "normal"}	2026-03-07 18:36:34.493311+03
708	f98044f3-8ac9-4219-a06b-097e230667e7	powerup_used	{"powerup": "shield", "duration": 14}	2026-03-07 18:44:50.197088+03
709	f98044f3-8ac9-4219-a06b-097e230667e7	level_end	{"level": 2, "score": 161, "success": true}	2026-03-07 19:08:53.840778+03
710	f98044f3-8ac9-4219-a06b-097e230667e7	level_end	{"level": 1, "score": 327, "success": true}	2026-03-07 18:34:19.75797+03
711	f98044f3-8ac9-4219-a06b-097e230667e7	level_start	{"level": 4, "difficulty": "easy"}	2026-03-07 18:33:48.160965+03
712	f98044f3-8ac9-4219-a06b-097e230667e7	level_end	{"level": 7, "score": 420, "success": true}	2026-03-07 18:35:11.907354+03
713	f98044f3-8ac9-4219-a06b-097e230667e7	enemy_killed	{"position": {"x": 26, "y": 54}, "enemy_type": "troll"}	2026-03-07 18:55:26.412226+03
714	f98044f3-8ac9-4219-a06b-097e230667e7	pause	{}	2026-03-07 18:45:06.291366+03
715	f98044f3-8ac9-4219-a06b-097e230667e7	enemy_killed	{"position": {"x": 30, "y": 26}, "enemy_type": "troll"}	2026-03-07 18:55:39.364481+03
716	f98044f3-8ac9-4219-a06b-097e230667e7	level_end	{"level": 7, "score": 518, "success": true}	2026-03-07 18:45:53.551871+03
717	f98044f3-8ac9-4219-a06b-097e230667e7	resume	{}	2026-03-07 18:51:37.243744+03
718	1c454144-dda2-4053-a6e0-e229959a12a0	player_died	{"position": {"x": 60, "y": 23}, "enemy_nearby": false}	2026-02-27 14:24:27.420522+03
719	1c454144-dda2-4053-a6e0-e229959a12a0	enemy_killed	{"position": {"x": 84, "y": 84}, "enemy_type": "goblin"}	2026-02-27 14:24:37.493436+03
720	1c454144-dda2-4053-a6e0-e229959a12a0	player_died	{"position": {"x": 61, "y": 87}, "enemy_nearby": true}	2026-02-27 14:24:17.667352+03
721	1c454144-dda2-4053-a6e0-e229959a12a0	powerup_used	{"powerup": "shield", "duration": 9}	2026-02-27 14:22:27.687564+03
722	1c454144-dda2-4053-a6e0-e229959a12a0	checkpoint_reached	{"checkpoint": 1}	2026-02-27 14:22:19.777857+03
723	1c454144-dda2-4053-a6e0-e229959a12a0	player_died	{"position": {"x": 35, "y": 95}, "enemy_nearby": true}	2026-02-27 14:20:26.366912+03
724	1c454144-dda2-4053-a6e0-e229959a12a0	pause	{}	2026-02-27 14:21:45.766182+03
725	1c454144-dda2-4053-a6e0-e229959a12a0	pause	{}	2026-02-27 14:22:26.478103+03
726	1c454144-dda2-4053-a6e0-e229959a12a0	checkpoint_reached	{"checkpoint": 4}	2026-02-27 14:20:58.205486+03
727	1c454144-dda2-4053-a6e0-e229959a12a0	player_died	{"position": {"x": 51, "y": 1}, "enemy_nearby": false}	2026-02-27 14:20:49.797083+03
728	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	level_start	{"level": 3, "difficulty": "hard"}	2026-03-12 23:13:38.573429+03
729	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	player_died	{"position": {"x": 2, "y": 50}, "enemy_nearby": true}	2026-03-12 22:59:07.936619+03
730	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	level_end	{"level": 5, "score": 244, "success": false}	2026-03-12 22:53:53.070079+03
731	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	player_died	{"position": {"x": 7, "y": 65}, "enemy_nearby": true}	2026-03-12 22:57:56.894274+03
732	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	checkpoint_reached	{"checkpoint": 3}	2026-03-12 22:47:31.445192+03
733	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	pause	{}	2026-03-12 22:58:18.000158+03
734	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	resume	{}	2026-03-12 23:02:14.983419+03
735	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	checkpoint_reached	{"checkpoint": 2}	2026-03-12 23:04:45.774225+03
736	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	menu_open	{}	2026-03-12 23:06:45.493812+03
737	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	enemy_killed	{"position": {"x": 45, "y": 55}, "enemy_type": "goblin"}	2026-03-12 23:18:58.391987+03
738	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	checkpoint_reached	{"checkpoint": 3}	2026-03-12 23:24:04.849368+03
739	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	resume	{}	2026-03-12 22:49:10.797255+03
740	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	checkpoint_reached	{"checkpoint": 5}	2026-03-12 22:57:43.131165+03
741	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	pause	{}	2026-03-12 23:19:17.772999+03
742	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	item_collected	{"item": "key", "value": 33}	2026-03-12 23:12:29.523347+03
743	5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	player_died	{"position": {"x": 39, "y": 28}, "enemy_nearby": true}	2026-03-12 22:47:57.917523+03
744	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	pause	{}	2026-02-15 18:14:42.512438+03
745	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	resume	{}	2026-02-15 18:22:51.79614+03
746	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	item_collected	{"item": "gem", "value": 17}	2026-02-15 18:37:32.348593+03
747	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	item_collected	{"item": "gem", "value": 12}	2026-02-15 18:12:54.310399+03
748	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	player_died	{"position": {"x": 79, "y": 16}, "enemy_nearby": true}	2026-02-15 18:35:56.469929+03
749	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	resume	{}	2026-02-15 17:57:42.617206+03
750	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	level_start	{"level": 10, "difficulty": "normal"}	2026-02-15 18:22:30.178918+03
751	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	resume	{}	2026-02-15 18:25:44.462131+03
752	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	menu_open	{}	2026-02-15 17:55:56.120232+03
753	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	level_end	{"level": 2, "score": 16, "success": true}	2026-02-15 18:08:14.041057+03
754	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	menu_open	{}	2026-02-15 18:36:12.559996+03
755	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	level_start	{"level": 7, "difficulty": "normal"}	2026-02-15 18:26:59.879078+03
756	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	player_died	{"position": {"x": 60, "y": 41}, "enemy_nearby": true}	2026-02-15 18:16:35.93836+03
757	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	checkpoint_reached	{"checkpoint": 1}	2026-02-15 18:30:15.84629+03
758	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	checkpoint_reached	{"checkpoint": 3}	2026-02-15 18:30:30.787101+03
759	26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	resume	{}	2026-02-15 18:36:46.691171+03
760	d80951e7-437a-4d11-87c9-1cc453db56de	level_start	{"level": 3, "difficulty": "easy"}	2026-02-28 19:15:42.853551+03
761	d80951e7-437a-4d11-87c9-1cc453db56de	player_died	{"position": {"x": 10, "y": 57}, "enemy_nearby": false}	2026-02-28 19:12:37.483507+03
762	d80951e7-437a-4d11-87c9-1cc453db56de	powerup_used	{"powerup": "speed", "duration": 6}	2026-02-28 19:07:52.787957+03
763	d80951e7-437a-4d11-87c9-1cc453db56de	menu_open	{}	2026-02-28 19:02:09.710833+03
764	d80951e7-437a-4d11-87c9-1cc453db56de	checkpoint_reached	{"checkpoint": 2}	2026-02-28 18:44:05.142412+03
765	d80951e7-437a-4d11-87c9-1cc453db56de	enemy_killed	{"position": {"x": 44, "y": 23}, "enemy_type": "goblin"}	2026-02-28 18:54:37.970643+03
766	d80951e7-437a-4d11-87c9-1cc453db56de	level_end	{"level": 6, "score": 607, "success": true}	2026-02-28 19:05:32.888295+03
767	d80951e7-437a-4d11-87c9-1cc453db56de	level_end	{"level": 2, "score": 134, "success": false}	2026-02-28 18:53:44.007964+03
768	d80951e7-437a-4d11-87c9-1cc453db56de	enemy_killed	{"position": {"x": 18, "y": 56}, "enemy_type": "goblin"}	2026-02-28 19:08:45.186925+03
769	d80951e7-437a-4d11-87c9-1cc453db56de	checkpoint_reached	{"checkpoint": 5}	2026-02-28 19:20:19.121659+03
770	d80951e7-437a-4d11-87c9-1cc453db56de	enemy_killed	{"position": {"x": 72, "y": 80}, "enemy_type": "goblin"}	2026-02-28 18:44:24.290318+03
771	d80951e7-437a-4d11-87c9-1cc453db56de	powerup_used	{"powerup": "shield", "duration": 7}	2026-02-28 19:00:33.188593+03
772	d80951e7-437a-4d11-87c9-1cc453db56de	level_end	{"level": 6, "score": 292, "success": true}	2026-02-28 18:55:38.416107+03
773	d80951e7-437a-4d11-87c9-1cc453db56de	powerup_used	{"powerup": "speed", "duration": 14}	2026-02-28 18:56:17.658241+03
774	d80951e7-437a-4d11-87c9-1cc453db56de	resume	{}	2026-02-28 18:57:29.748389+03
775	d80951e7-437a-4d11-87c9-1cc453db56de	checkpoint_reached	{"checkpoint": 2}	2026-02-28 19:15:28.307778+03
776	d80951e7-437a-4d11-87c9-1cc453db56de	level_end	{"level": 10, "score": 688, "success": true}	2026-02-28 19:18:39.169477+03
777	d80951e7-437a-4d11-87c9-1cc453db56de	pause	{}	2026-02-28 18:43:43.184603+03
778	d80951e7-437a-4d11-87c9-1cc453db56de	player_died	{"position": {"x": 99, "y": 77}, "enemy_nearby": true}	2026-02-28 19:07:38.858361+03
779	e0918745-15e9-466b-9e97-6433fa34344e	item_collected	{"item": "key", "value": 0}	2026-02-25 01:27:40.002374+03
780	e0918745-15e9-466b-9e97-6433fa34344e	item_collected	{"item": "key", "value": 36}	2026-02-25 01:29:36.897043+03
781	e0918745-15e9-466b-9e97-6433fa34344e	item_collected	{"item": "key", "value": 24}	2026-02-25 01:26:09.824478+03
782	e0918745-15e9-466b-9e97-6433fa34344e	player_died	{"position": {"x": 18, "y": 70}, "enemy_nearby": false}	2026-02-25 01:28:57.789079+03
783	e0918745-15e9-466b-9e97-6433fa34344e	player_died	{"position": {"x": 30, "y": 8}, "enemy_nearby": true}	2026-02-25 01:28:58.825954+03
784	e0918745-15e9-466b-9e97-6433fa34344e	checkpoint_reached	{"checkpoint": 1}	2026-02-25 01:23:15.782965+03
785	e0918745-15e9-466b-9e97-6433fa34344e	checkpoint_reached	{"checkpoint": 3}	2026-02-25 01:27:53.127021+03
786	e0918745-15e9-466b-9e97-6433fa34344e	checkpoint_reached	{"checkpoint": 4}	2026-02-25 01:24:48.956896+03
787	e0918745-15e9-466b-9e97-6433fa34344e	item_collected	{"item": "gem", "value": 5}	2026-02-25 01:21:18.536035+03
788	e0918745-15e9-466b-9e97-6433fa34344e	item_collected	{"item": "coin", "value": 25}	2026-02-25 01:34:14.056257+03
789	e0918745-15e9-466b-9e97-6433fa34344e	menu_open	{}	2026-02-25 01:29:56.310898+03
790	e0918745-15e9-466b-9e97-6433fa34344e	player_died	{"position": {"x": 15, "y": 88}, "enemy_nearby": true}	2026-02-25 01:40:40.342615+03
791	e0918745-15e9-466b-9e97-6433fa34344e	pause	{}	2026-02-25 01:27:46.523338+03
792	e0918745-15e9-466b-9e97-6433fa34344e	level_start	{"level": 9, "difficulty": "hard"}	2026-02-25 01:40:08.654639+03
\.


--
-- Data for Name: players; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.players (player_id, created_at, last_session_id, total_playtime) FROM stdin;
player_alpha	2026-02-14 22:25:28.445495+03	\N	15:00:00
player_beta	2026-02-24 22:25:28.445495+03	\N	25:00:00
player_gamma	2026-03-06 22:25:28.445495+03	\N	05:00:00
player_delta	2026-03-11 22:25:28.445495+03	\N	02:00:00
player_epsilon	2026-03-15 22:25:28.445495+03	\N	00:30:00
\.


--
-- Data for Name: predictions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.predictions (prediction_id, session_id, player_id, prediction_type, prediction_value, model_version, created_at) FROM stdin;
\.


--
-- Data for Name: session_features; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session_features (feature_id, session_id, feature_name, feature_value, calculated_at) FROM stdin;
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sessions (session_id, player_id, started_at, ended_at, game_version) FROM stdin;
84527aad-b7d2-42ce-99be-c7663751a159	player_gamma	2026-02-17 07:35:22.413213+03	2026-02-17 07:54:27.543668+03	1.0.0
8767cd93-cb20-4018-bb77-490fe7f736a6	player_epsilon	2026-03-16 01:40:50.836428+03	2026-03-16 02:20:26.302065+03	1.0.0
c97b9dc0-4bb9-4cb3-b9b3-660d3470812c	player_alpha	2026-03-09 02:45:17.317071+03	2026-03-09 03:13:07.29581+03	1.0.0
19de7cd4-c9ed-4d17-881e-c608a33ff081	player_epsilon	2026-03-09 05:01:25.640868+03	2026-03-09 05:08:14.848134+03	1.0.0
65865201-0ab0-49cc-bbbc-f57130f7c2ca	player_beta	2026-03-01 08:47:35.907668+03	2026-03-01 09:06:27.263712+03	1.0.0
85d48362-04aa-4eb0-9404-cd7e95374bf3	player_beta	2026-02-16 05:41:40.552231+03	2026-02-16 06:01:27.162062+03	1.0.0
2a50968a-e764-4f78-9a3e-15e86cf6a168	player_gamma	2026-03-07 07:40:07.708714+03	2026-03-07 12:20:30.270502+03	1.1.0
348ca824-cf69-48e6-81e8-23c67b74b7d3	player_alpha	2026-02-18 14:26:35.574145+03	2026-02-18 15:09:48.877404+03	1.0.0
9fdd7b3d-7f32-414b-ac22-f84bf1b11e35	player_gamma	2026-03-12 11:52:00.416259+03	2026-03-12 11:58:45.364272+03	1.0.0
ee3a21e0-4fad-44e6-b1ba-0125b697618c	player_gamma	2026-03-05 19:24:50.720661+03	2026-03-05 19:49:13.949178+03	1.0.0
1767d3bb-8172-487a-84b6-d01c1bca5826	player_gamma	2026-02-25 15:49:37.655906+03	2026-02-25 16:13:37.128525+03	1.0.0
9331511e-e127-4b41-be2f-8285e6767392	player_delta	2026-03-16 19:31:44.362485+03	2026-03-16 20:00:09.939459+03	1.0.0
b4ee6051-9957-4887-b1bc-30ef3771f951	player_delta	2026-03-10 17:21:42.755536+03	2026-03-10 17:38:11.464582+03	1.0.0
f8cdc801-12ec-4a18-9fee-0bdb0d37961c	player_delta	2026-03-10 21:47:45.685733+03	2026-03-10 22:39:00.554619+03	1.0.0
d4724f70-dffc-4c62-a196-b0e6deed6dce	player_alpha	2026-03-10 17:41:26.051587+03	2026-03-10 18:26:35.153962+03	1.1.0
ef51adb8-14a6-4af8-8d96-268d8ca1e436	player_gamma	2026-03-12 06:23:02.224338+03	2026-03-12 07:10:30.741446+03	1.0.0
6634dee1-6f84-4729-b002-77e4e37081da	player_beta	2026-03-03 15:32:03.421478+03	2026-03-03 16:26:56.189966+03	1.0.0
b9314229-8b2b-45a7-815f-3f5394a124aa	player_alpha	2026-03-02 08:50:39.896507+03	2026-03-02 08:57:21.136516+03	1.0.0
5244b4d7-59e0-4922-936e-026430b6df09	player_gamma	2026-03-12 16:56:09.398536+03	2026-03-12 17:18:19.149309+03	1.0.0
fb742483-f64d-4932-9581-5b6ad40b92cc	player_beta	2026-02-25 03:18:06.239957+03	2026-02-25 03:37:31.823437+03	1.1.0
c0668173-ffe1-47b9-9619-9da7da7cc2bf	player_gamma	2026-03-10 21:24:18.87758+03	2026-03-11 01:46:07.450625+03	1.0.0
a46edd96-cbc8-4eea-bc43-9a95e55b42c3	player_alpha	2026-02-16 02:52:03.105863+03	2026-02-16 03:12:39.683095+03	1.0.0
ab6908e7-2b42-4617-b06d-ece8bfb2cccd	player_delta	2026-02-16 15:16:26.795829+03	2026-02-16 15:54:02.258154+03	1.1.0
9ee44003-00e7-4c49-94e8-74b44f116f12	player_beta	2026-03-10 11:26:53.617065+03	2026-03-10 12:00:45.626116+03	1.1.0
74e35c49-1e10-44b4-bda8-4052aa441baf	player_delta	2026-03-04 09:07:29.933085+03	2026-03-04 11:54:53.300618+03	1.0.0
ad52df3e-a9d0-4818-bce5-ed472bd371c0	player_beta	2026-03-11 00:15:56.737258+03	2026-03-11 02:54:20.203635+03	1.0.0
100daaff-d23e-412c-b135-44eb853b9a1a	player_beta	2026-03-08 23:11:36.20432+03	2026-03-08 23:43:44.580034+03	1.0.0
bbdec12a-90aa-41a4-8f43-a23bb151a48e	player_gamma	2026-02-16 23:18:10.716392+03	2026-02-17 00:13:33.487265+03	1.0.0
092539cc-204d-4bac-9f11-56f4926891e2	player_delta	2026-03-12 06:26:05.27202+03	2026-03-12 07:25:05.243639+03	1.0.0
413a7c3e-813b-496d-8587-5698b6b471a5	player_gamma	2026-02-26 09:59:59.774591+03	2026-02-26 14:22:36.136052+03	1.1.0
42513389-596d-44e9-ae82-c4d1734a4ab6	player_gamma	2026-03-08 21:44:28.995802+03	2026-03-08 22:08:59.320081+03	1.1.0
09513d13-78d5-436a-a25e-ca8abdb5ad08	player_gamma	2026-03-09 08:32:33.357022+03	2026-03-09 08:48:22.336579+03	1.0.0
72ef4b97-f523-41ed-9d52-025d754a712a	player_epsilon	2026-03-11 10:23:03.58513+03	2026-03-11 10:27:07.234926+03	1.1.0
a1f0a834-127d-4362-8793-702b6448b0bc	player_epsilon	2026-02-19 01:42:41.090726+03	2026-02-19 02:32:07.888913+03	1.0.0
315936c8-08fe-40d3-a87c-3bbcd372f8c7	player_alpha	2026-03-11 15:42:37.425627+03	2026-03-11 16:15:34.586537+03	1.0.0
e0aa7abf-fd5b-44da-90ad-10620810a67e	player_delta	2026-02-19 05:43:13.23157+03	2026-02-19 05:59:28.514653+03	1.1.0
e020f5e8-8edb-4a9b-8958-2036dc805b2a	player_gamma	2026-03-08 04:28:09.203314+03	2026-03-08 05:02:23.385842+03	1.0.0
4417fcd8-656b-47b6-b7b9-d4ada88e2ab1	player_epsilon	2026-02-24 05:33:26.86718+03	2026-02-24 05:54:01.359124+03	1.0.0
3d23b256-471c-4afa-ba12-4d3a9357fb45	player_alpha	2026-03-06 21:34:58.900029+03	2026-03-06 22:11:28.923049+03	1.1.0
1175f786-f0c0-484b-bc70-b0475448eae3	player_delta	2026-03-06 15:55:00.238691+03	2026-03-06 18:35:28.243513+03	1.0.0
95437a5d-b0ae-4de1-89cb-de3b11281899	player_gamma	2026-02-15 06:16:57.903937+03	2026-02-15 06:54:26.221815+03	1.0.0
0fb0688b-52b1-4740-9899-c24cdac441c7	player_beta	2026-02-19 21:57:16.12595+03	2026-02-19 22:43:46.247769+03	1.0.0
d0bb2bcc-f3eb-4837-a708-eb884826d2fb	player_beta	2026-03-14 02:57:17.991447+03	2026-03-14 03:36:02.490141+03	1.0.0
335853f3-5eec-4031-b940-28ff6d0c0e6b	player_gamma	2026-03-16 00:33:28.665239+03	2026-03-16 01:26:33.204164+03	1.1.0
9168908f-37ed-4522-ada0-e7c5642bb29b	player_epsilon	2026-02-18 14:30:32.336537+03	2026-02-18 15:10:19.699498+03	1.1.0
8a9cfc9d-4c1c-41d2-a779-bf11e7f98296	player_gamma	2026-03-12 03:25:11.304352+03	2026-03-12 03:49:20.995237+03	1.0.0
ae0161eb-0665-48c5-907c-bf763b9983b8	player_delta	2026-02-16 00:04:49.754709+03	2026-02-16 00:36:10.303993+03	1.0.0
4dcf3546-438d-4414-afce-5d62bb078009	player_gamma	2026-03-05 16:12:51.626428+03	2026-03-05 16:35:04.375916+03	1.1.0
54b7ae9e-1970-4c51-8f9e-2a9f6a015a9a	player_beta	2026-02-15 05:22:30.890119+03	2026-02-15 06:13:23.374437+03	1.0.0
0895303e-8bb6-4cab-9156-ba03a996fd25	player_alpha	2026-02-28 22:22:03.086799+03	2026-03-01 02:19:51.318266+03	1.0.0
334cc212-8138-462c-b1ef-0fee08d08a05	player_delta	2026-02-19 22:47:57.333529+03	2026-02-19 23:26:27.938845+03	1.1.0
b00e3f58-6c36-44da-8942-a007e9ab163a	player_gamma	2026-03-09 18:52:20.09213+03	2026-03-09 21:44:44.647869+03	1.0.0
b6deebbc-330b-4c95-9cb5-91de68dd983f	player_gamma	2026-03-16 06:44:37.238556+03	2026-03-16 06:49:21.339438+03	1.0.0
9880da5f-a1fe-4427-ab2d-745853339acd	player_delta	2026-03-09 23:24:08.59515+03	2026-03-10 00:10:15.660604+03	1.1.0
f98044f3-8ac9-4219-a06b-097e230667e7	player_epsilon	2026-03-07 18:33:20.604243+03	2026-03-07 19:15:11.762778+03	1.0.0
1c454144-dda2-4053-a6e0-e229959a12a0	player_epsilon	2026-02-27 14:19:55.109446+03	2026-02-27 14:25:14.628959+03	1.0.0
5bfc9835-a015-4a8a-aa4f-b522c5ac6cc3	player_epsilon	2026-03-12 22:38:32.546813+03	2026-03-12 23:24:15.822201+03	1.0.0
26483abe-716f-4e7d-8e6b-96c6ce9bf0c7	player_epsilon	2026-02-15 17:55:37.060898+03	2026-02-15 18:37:48.180322+03	1.0.0
d80951e7-437a-4d11-87c9-1cc453db56de	player_beta	2026-02-28 18:42:48.106458+03	2026-02-28 19:21:30.430721+03	1.1.0
e0918745-15e9-466b-9e97-6433fa34344e	player_epsilon	2026-02-25 01:17:26.788703+03	2026-02-25 01:41:30.42627+03	1.1.0
\.


--
-- Name: adaptation_history_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.adaptation_history_history_id_seq', 1, false);


--
-- Name: adaptation_state_adaptation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.adaptation_state_adaptation_id_seq', 1, false);


--
-- Name: events_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.events_event_id_seq', 792, true);


--
-- Name: predictions_prediction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.predictions_prediction_id_seq', 1, false);


--
-- Name: session_features_feature_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.session_features_feature_id_seq', 1, false);


--
-- Name: adaptation_history adaptation_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adaptation_history
    ADD CONSTRAINT adaptation_history_pkey PRIMARY KEY (history_id);


--
-- Name: adaptation_state adaptation_state_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adaptation_state
    ADD CONSTRAINT adaptation_state_pkey PRIMARY KEY (adaptation_id);


--
-- Name: adaptation_state adaptation_state_session_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adaptation_state
    ADD CONSTRAINT adaptation_state_session_id_key UNIQUE (session_id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (event_id);


--
-- Name: players players_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.players
    ADD CONSTRAINT players_pkey PRIMARY KEY (player_id);


--
-- Name: predictions predictions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.predictions
    ADD CONSTRAINT predictions_pkey PRIMARY KEY (prediction_id);


--
-- Name: session_features session_features_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_features
    ADD CONSTRAINT session_features_pkey PRIMARY KEY (feature_id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (session_id);


--
-- Name: idx_adaptation_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_adaptation_session ON public.adaptation_state USING btree (session_id);


--
-- Name: idx_events_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_created_at ON public.events USING btree (created_at);


--
-- Name: idx_events_session_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_session_id ON public.events USING btree (session_id);


--
-- Name: idx_predictions_player; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_predictions_player ON public.predictions USING btree (player_id);


--
-- Name: idx_predictions_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_predictions_session ON public.predictions USING btree (session_id);


--
-- Name: idx_session_features_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_session_features_session ON public.session_features USING btree (session_id);


--
-- Name: adaptation_history adaptation_history_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adaptation_history
    ADD CONSTRAINT adaptation_history_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(player_id) ON DELETE CASCADE;


--
-- Name: adaptation_history adaptation_history_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adaptation_history
    ADD CONSTRAINT adaptation_history_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(session_id) ON DELETE CASCADE;


--
-- Name: adaptation_state adaptation_state_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adaptation_state
    ADD CONSTRAINT adaptation_state_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(player_id) ON DELETE CASCADE;


--
-- Name: adaptation_state adaptation_state_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adaptation_state
    ADD CONSTRAINT adaptation_state_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(session_id) ON DELETE CASCADE;


--
-- Name: events events_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(session_id);


--
-- Name: predictions predictions_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.predictions
    ADD CONSTRAINT predictions_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(player_id) ON DELETE CASCADE;


--
-- Name: predictions predictions_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.predictions
    ADD CONSTRAINT predictions_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(session_id) ON DELETE CASCADE;


--
-- Name: session_features session_features_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_features
    ADD CONSTRAINT session_features_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(session_id) ON DELETE CASCADE;


--
-- Name: sessions sessions_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(player_id);


--
-- PostgreSQL database dump complete
--

\unrestrict lJX8ybW1PziAr9tnMIsmV2uzymvKmFAQg6UISBeuDmADRqVRBgz0XgLPZyWFZkg

