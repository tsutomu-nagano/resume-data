--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.4 (Debian 16.4-1.pgdg120+1)

--
-- Name: dimension_item; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.dimension_item (
    "class.name" VARCHAR(255) NOT NULL,
    name VARCHAR(500) NOT NULL
);


ALTER TABLE public.dimension_item OWNER TO statmetadata_owner;

--
-- Name: dimensionlist; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.dimensionlist (
    "class.name" VARCHAR(255) NOT NULL
);


ALTER TABLE public.dimensionlist OWNER TO statmetadata_owner;


--
-- Name: measurelist; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.measurelist (
    "name" VARCHAR(500) NOT NULL
);


ALTER TABLE public.measurelist OWNER TO statmetadata_owner;

--
-- Name: measurelist; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.regionlist (
    "class.name" VARCHAR(255) NOT NULL
);


ALTER TABLE public.regionlist OWNER TO statmetadata_owner;


--
-- Name: region_item; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.region_item (
    "class.name" VARCHAR(255) NOT NULL,
    name VARCHAR(500) NOT NULL
);


ALTER TABLE public.region_item OWNER TO statmetadata_owner;


--
-- Name: govlist; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.govlist (
    govcode VARCHAR(255) NOT NULL,
    govname VARCHAR(255) NOT NULL
);


ALTER TABLE public.govlist OWNER TO statmetadata_owner;

--
-- Name: TABLE govlist; Type: COMMENT; Schema: public; Owner: statmetadata_owner
--

COMMENT ON TABLE public.govlist IS '府省名の一覧';


--
-- Name: statlist; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.statlist (
    statcode VARCHAR(255) NOT NULL,
    statname VARCHAR(255) NOT NULL,
    govcode VARCHAR(255) NOT NULL
);


ALTER TABLE public.statlist OWNER TO statmetadata_owner;

--
-- Name: TABLE statlist; Type: COMMENT; Schema: public; Owner: statmetadata_owner
--

COMMENT ON TABLE public.statlist IS '統計調査の一覧';


--
-- Name: table_dimension; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.table_dimension (
    statdispid VARCHAR(255) NOT NULL,
    "class.name" VARCHAR(255) NOT NULL
);


ALTER TABLE public.table_dimension OWNER TO statmetadata_owner;

--
-- Name: table_measure; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.table_measure (
    statdispid VARCHAR(255) NOT NULL,
    name VARCHAR(500) NOT NULL
);


ALTER TABLE public.table_region OWNER TO statmetadata_owner;

--
-- Name: table_region; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.table_region (
    statdispid VARCHAR(255) NOT NULL,
    "class.name" VARCHAR(255) NOT NULL
);


ALTER TABLE public.table_region OWNER TO statmetadata_owner;


--
-- Name: table_tag; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.table_tag (
    statdispid VARCHAR(255) NOT NULL,
    tag_name VARCHAR(255) NOT NULL
);


ALTER TABLE public.table_tag OWNER TO statmetadata_owner;

--
-- Name: TABLE table_tag; Type: COMMENT; Schema: public; Owner: statmetadata_owner
--

COMMENT ON TABLE public.table_tag IS '統計表とタグの中間テーブル';


--
-- Name: tablelist; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.tablelist (
    statcode VARCHAR(255) NOT NULL,
    statdispid VARCHAR(255) NOT NULL,
    title text NOT NULL,
    cycle VARCHAR(255) NOT NULL,
    survey_date VARCHAR(255) NOT NULL
);


ALTER TABLE public.tablelist OWNER TO statmetadata_owner;

--
-- Name: TABLE tablelist; Type: COMMENT; Schema: public; Owner: statmetadata_owner
--

COMMENT ON TABLE public.tablelist IS '統計表の一覧';


--
-- Name: taglist; Type: TABLE; Schema: public; Owner: statmetadata_owner
--

CREATE TABLE public.taglist (
    tag_name VARCHAR(255) NOT NULL
);


ALTER TABLE public.taglist OWNER TO statmetadata_owner;

--
-- Name: TABLE taglist; Type: COMMENT; Schema: public; Owner: statmetadata_owner
--

COMMENT ON TABLE public.taglist IS 'タグの一覧';


--
-- Name: dimension_item dimension_item_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.dimension_item
    ADD CONSTRAINT dimension_item_pkey PRIMARY KEY ("class.name", name);


--
-- Name: dimensionlist dimensionlist_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.dimensionlist
    ADD CONSTRAINT dimensionlist_pkey PRIMARY KEY ("class.name");



--
-- Name: region_item region_item_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.region_item
    ADD CONSTRAINT region_item_pkey PRIMARY KEY ("class.name", name);


--
-- Name: regionlist regionlist_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.regionlist
    ADD CONSTRAINT resionlist_pkey PRIMARY KEY ("class.name");

--
-- Name: mesurelist mesurelist_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.measurelist
    ADD CONSTRAINT measurelist_pkey PRIMARY KEY ("name");


--
-- Name: govlist govlist_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.govlist
    ADD CONSTRAINT govlist_pkey PRIMARY KEY (govcode);


--
-- Name: statlist statlist_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.statlist
    ADD CONSTRAINT statlist_pkey PRIMARY KEY (statcode);


--
-- Name: table_dimension table_dimension_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_dimension
    ADD CONSTRAINT table_dimension_pkey PRIMARY KEY (statdispid, "class.name");


--
-- Name: table_region table_region_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_region
    ADD CONSTRAINT table_region_pkey PRIMARY KEY (statdispid, "class.name");

--
-- Name: table_measure table_measure_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_measure
    ADD CONSTRAINT table_measure_pkey PRIMARY KEY (statdispid, name);


--
-- Name: table_tag table_tag_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_tag
    ADD CONSTRAINT table_tag_pkey PRIMARY KEY (statdispid, tag_name);


--
-- Name: tablelist tablelist_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.tablelist
    ADD CONSTRAINT tablelist_pkey PRIMARY KEY (statdispid);


--
-- Name: taglist taglist_pkey; Type: CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.taglist
    ADD CONSTRAINT taglist_pkey PRIMARY KEY (tag_name);


--
-- Name: dimension_item dimension_item_class.name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.dimension_item
    ADD CONSTRAINT "dimension_item_class.name_fkey" FOREIGN KEY ("class.name") REFERENCES public.dimensionlist("class.name") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: region_item region_item_class.name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.region_item
    ADD CONSTRAINT "region_item_class.name_fkey" FOREIGN KEY ("class.name") REFERENCES public.regionlist("class.name") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: statlist statlist_govcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.statlist
    ADD CONSTRAINT statlist_govcode_fkey FOREIGN KEY (govcode) REFERENCES public.govlist(govcode) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: table_dimension table_dimension_class.name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_dimension
    ADD CONSTRAINT "table_dimension_class.name_fkey" FOREIGN KEY ("class.name") REFERENCES public.dimensionlist("class.name") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: table_dimension table_dimension_statdispid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_dimension
    ADD CONSTRAINT table_dimension_statdispid_fkey FOREIGN KEY (statdispid) REFERENCES public.tablelist(statdispid) ON UPDATE SET NULL ON DELETE SET NULL;



--
-- Name: table_region table_region_class.name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_region
    ADD CONSTRAINT "table_region_class.name_fkey" FOREIGN KEY ("class.name") REFERENCES public.regionlist("class.name") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: table_region table_region_statdispid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_region
    ADD CONSTRAINT table_region_statdispid_fkey FOREIGN KEY (statdispid) REFERENCES public.tablelist(statdispid) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: table_measure table_measure_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_measure
    ADD CONSTRAINT table_measure_name_fkey FOREIGN KEY (name) REFERENCES public.measurelist(name) ON UPDATE RESTRICT ON DELETE RESTRICT;



--
-- Name: table_measure table_measure_statdispid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_measure
    ADD CONSTRAINT table_measure_statdispid_fkey FOREIGN KEY (statdispid) REFERENCES public.tablelist(statdispid) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: table_tag table_tag_statdispid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_tag
    ADD CONSTRAINT table_tag_statdispid_fkey FOREIGN KEY (statdispid) REFERENCES public.tablelist(statdispid) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: table_tag table_tag_tag_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.table_tag
    ADD CONSTRAINT table_tag_tag_name_fkey FOREIGN KEY (tag_name) REFERENCES public.taglist(tag_name) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: tablelist tablelist_statcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: statmetadata_owner
--

ALTER TABLE ONLY public.tablelist
    ADD CONSTRAINT tablelist_statcode_fkey FOREIGN KEY (statcode) REFERENCES public.statlist(statcode) ON UPDATE SET NULL ON DELETE SET NULL;


