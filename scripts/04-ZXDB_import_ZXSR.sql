-- [ZXDB] Import Chris Bourne's ZXSR tables into ZXDB
-- by Einar Saukas

USE zxdb;

-- BUGFIXES!
-- update zxsr.ssd_review_score_compilations c set game_id=746 where game_id=853;   -- Buggy Boy
-- update zxsr.ssd_review_score_compilations c set game_id=2482 where game_id=2483; -- Infiltrator
select * from zxsr.ssd_review_picture s where s.ReviewId not in (select review_id from zxsr.ssd_review);

-- Delete previous ZXSR imports
delete from zxsr_captions where 1=1;
-- delete from zxsr_scores where 1=1;
delete from zxsr_scores where magref_id not in (select r.id from magrefs r inner join issues i on r.issue_id = i.id where i.magazine_id in (150,322));
select * from magrefs where id >= 300000;
delete from magreffeats where magref_id >= 300000;
delete from magrefs where id >= 300000;
update magrefs set review_id = null where 1=1;
-- update magrefs set award_id = null where 1=1;
update magrefs set award_id = null where award_id not in (1,50);
update magrefs set score_group='' where score_group not in ('Classic Adventure','Colossal Caves');
delete from zxsr_reviews where 1=1;

-- Store review text in ZXDB
insert into zxsr_reviews(id, review_text, review_comments, review_rating, reviewers) (select text_id, replace(review_text,'\r',''), replace(replace(review_comments,'\r',''),'¬','\n\n\n\n'), replace(review_rating,'\r',''), reviewers from zxsr.ssd_review_text);

update zxsr_reviews set review_text = SUBSTR(review_text,2) where review_text like '\n%';
update zxsr_reviews set review_text = SUBSTR(review_text,1,CHAR_LENGTH(review_text)-1) where review_text like '%\n';
update zxsr_reviews set review_text = SUBSTR(review_text,1,CHAR_LENGTH(review_text)-1) where review_text like '%\n';

update zxsr_reviews set review_comments = SUBSTR(review_comments,1,CHAR_LENGTH(review_comments)-1) where review_comments like '%\n';

update zxsr_reviews set review_rating = SUBSTR(review_rating,1,CHAR_LENGTH(review_rating)-1) where review_rating like '%\n';
update zxsr_reviews set review_rating = SUBSTR(review_rating,1,CHAR_LENGTH(review_rating)-1) where review_rating like '%\n';
update zxsr_reviews set review_rating = SUBSTR(review_rating,1,CHAR_LENGTH(review_rating)-1) where review_rating like '%\n';

-- Associate reviews between ZXSR and ZXDB
create table tmp_review (
    id int(11) not null primary key,
    magref_id int(11) unique,
    page smallint(6) not null,
    score_group varchar(100) not null default '',
    variant tinyint(4) not null default 0,
    constraint fk_tmp_review_magref foreign key (magref_id) references magrefs(id)
);

insert into tmp_review (id, page) (select review_id, trim(substring_index(replace(replace(lower(review_page),'(supplement)',''),'.',','),',',1)) from zxsr.ssd_review);

-- Whenever the same review of the same game appears twice in ZXSR, give each one a "score_group" name to distinguish between them
create table tmp_score_groups (
    entry_id int(11) not null,
    issue_id int(11) not null,
    page smallint(6) not null,
    overall_score varchar(255) not null,
    variant tinyint(4) not null,
    score_group varchar(100) not null,
    primary key(entry_id, issue_id, page, overall_score)
);

insert into tmp_score_groups (entry_id, issue_id, page, overall_score, variant, score_group) values
(176, 1007, 116, 92, 0, '48K'),         -- Amaurote
(176, 1007, 116, 94, 1, '128K'),
(2054, 1001, 18, 80, 0, '48K'),         -- Glider Rider
(2054, 1001, 18, 92, 1, '128K'),
(4863, 1003, 22, 95, 0, '48K'),         -- Starglider
(4863, 1003, 22, 97, 1, '128K'),
(5061, 995, 24, 86, 0, 'Pros'),         -- SuperCom
(5061, 995, 24, 21, 1, 'Cons'),
(4448, 94, 50, 85, 0, 'Charles Wood'),  -- Shark
(4448, 94, 50, 78, 1, 'Garth Sumpter'),
(5218, 94, 50, 65, 0, 'Editor'),        -- Thanatos
(5218, 94, 50, 73, 1, 'Garth Sumpter'),
(5630, 94, 51, 35, 0, 'Andrew Buchan'), -- War Machine
(5630, 94, 51, 61, 1, 'Garth Sumpter'),
(2081, 298, 59, 30, 0, 'Standalone');   -- Golden Axe

update tmp_review t
inner join zxsr.ssd_review z on t.id = z.review_id
inner join zxsr.ssd_review_score s on t.id = s.review_id
inner join tmp_score_groups x on z.game_id = x.entry_id and z.zxdb_issue_id = x.issue_id and t.page = x.page
set t.variant = x.variant, t.score_group = x.score_group
where s.review_header='Overall' and s.review_score = x.overall_score;

drop table tmp_score_groups;

update tmp_review t
inner join zxsr.ssd_review z on t.id = z.review_id
inner join zxsr.ssd_review_text x on z.text_id = x.text_id
set t.variant = 0, t.score_group = 'Classic Adventure', t.magref_id = 99567
where z.game_id = 6087 and z.zxdb_issue_id = 971 and t.page = 73 and x.review_text like 'Producer: M%';

update tmp_review t
inner join zxsr.ssd_review z on t.id = z.review_id
inner join zxsr.ssd_review_text x on z.text_id = x.text_id
set t.variant = 1, t.score_group = 'Colossal Caves', t.magref_id = 237072
where z.game_id = 6087 and z.zxdb_issue_id = 971 and t.page = 73 and x.review_text like 'Producer: C%';

update tmp_review t
inner join zxsr.ssd_review z on t.id = z.review_id
inner join magrefs r on z.game_id = r.entry_id and z.zxdb_issue_id = r.issue_id and t.page = r.page
set t.magref_id = r.id, r.score_group = t.score_group
where t.variant = 0 and t.magref_id is null and r.score_group = '' and r.referencetype_id = 10;

-- Add a magazine reference in magrefs if it's not already there
insert into magrefs(id, referencetype_id, entry_id, issue_id, page, score_group) (select 300000+t.id, 10, z.game_id, z.zxdb_issue_id, t.page, t.score_group from tmp_review t inner join zxsr.ssd_review z on z.review_id = t.id where t.magref_id is null);

update tmp_review set magref_id = 300000+id where magref_id is null;

-- Store review information in magrefs
update magrefs r inner join tmp_review t on r.id = t.magref_id inner join zxsr.ssd_review z on t.id = z.review_id set r.award_id = if(z.award_id<>999, z.award_id, null), r.review_id = z.text_id where 1=1;

-- Store review scores in ZXDB
insert into zxsr_scores(magref_id, score_seq, category, is_overall, score, comments) (select t.magref_id, s.header_order, s.review_header, 0, nullif(concat(coalesce(trim(s.review_score),''),coalesce(trim(s.score_suffix),'')),''), nullif(replace(s.score_text,'\r',''),'') from tmp_review t inner join zxsr.ssd_review_score s on s.review_id = t.id order by t.magref_id, s.header_order);

-- Add a reference to the compilation content's review in ZXDB if it's not already there
insert into magrefs(id, referencetype_id, entry_id, issue_id, page, score_group, review_id) (select 350000+c.score_id, 10, c.game_id, z.zxdb_issue_id, t.page, if(c.game_id=2081,'Compilation',''), z.text_id from zxsr.ssd_review_score_compilations c inner join zxsr.ssd_review z on c.review_id = z.review_id inner join tmp_review t on z.review_id = t.id left join magrefs r on c.game_id = r.entry_id and z.zxdb_issue_id = r.issue_id and t.page = r.page and r.referencetype_id = 10 and r.score_group = '' where r.id is null group by c.game_id, z.zxdb_issue_id, t.page order by c.game_id, z.zxdb_issue_id, t.page);

-- Store compilation content's review information in magrefs
update zxsr.ssd_review_score_compilations c
inner join zxsr.ssd_review z on c.review_id = z.review_id
inner join tmp_review t on z.review_id = t.id
inner join magrefs r on c.game_id = r.entry_id and z.zxdb_issue_id = r.issue_id and t.page = r.page and r.referencetype_id = 10
set r.review_id = z.text_id
where r.review_id is null;

-- Store compilation content's review scores in ZXDB
insert into zxsr_scores(magref_id, score_seq, category, is_overall, score) (select r.id, if(c.review_header like '%(%',c.header_order,1), c.review_header, 0, nullif(concat(coalesce(trim(c.review_score),''),coalesce(trim(c.score_suffix),'')),'')
from zxsr.ssd_review_score_compilations c
inner join zxsr.ssd_review z on c.review_id = z.review_id
inner join tmp_review t on z.review_id = t.id
inner join magrefs r on c.game_id = r.entry_id and z.zxdb_issue_id = r.issue_id and t.page = r.page and r.referencetype_id = 10 and r.score_group <> 'Standalone'
order by r.id, c.header_order);

-- Identify overall scores
update zxsr_scores s1 left join zxsr_scores s2 on s1.magref_id = s2.magref_id and s2.score_seq > s1.score_seq set s1.is_overall = 1 where s2.magref_id is null and (s1.score_seq = 1 or s1.category = 'Ace Rating' or s1.category = 'ACE Rating' or s1.category = 'Verdict' or (s1.category like 'Overall%' and s1.category not like 'Overall (%') and s1.score not like '%K)');

-- Store review picture descriptions in ZXDB
alter table zxsr_captions drop primary key;
alter table zxsr_captions add column id int(11) not null primary key auto_increment;

insert into zxsr_captions(magref_id, caption_seq, text, is_banner) (select t.magref_id, 0, replace(p.pic_text,'\r',''), p.is_banner
from zxsr.ssd_review_picture s
inner join zxsr.ssd_review_picture_text p on s.text_id = p.text_id
inner join tmp_review t on s.ReviewId = t.id
order by t.magref_id, p.is_banner, p.pic_text);

-- Calculate review picture description sequences
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);
update zxsr_captions set caption_seq=(select max(caption_seq)+1 from zxsr_captions) where id in (select min(id) from zxsr_captions where caption_seq=0 group by magref_id);

alter table zxsr_captions modify id int(11);
alter table zxsr_captions drop primary key, add primary key(magref_id,caption_seq);
alter table zxsr_captions drop column id;

drop table tmp_review;

-- END
