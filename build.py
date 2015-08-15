import datetime
import glob
import os
import shutil

import jinja2
import markdown
from pony.orm import *

def meta_from(line):
    '''Returns key, value or None from a line like "Key: Value" or "#tag"'''
    if line[0] == '#':
        return '#', line[1:].lstrip().rstrip()
    idx = line.find(':')
    if idx == -1:
        return None, None
    key = line[:idx].lstrip().rstrip()
    value = line[idx+1:].lstrip().rstrip()
    return key, value

def build():
    # First phase - load all items into an in-memory sqlite3 database
    ## Create the database
    db = Database('sqlite', ':memory:')
    # sql_debug(True)

    class Article(db.Entity):
        key = PrimaryKey(str)
        title = Required(str)
        precis = Optional(str)
        category = Required(str)
        publication = Required('Publication')
        page = Required(str)
        pub_date = Required(datetime.date)
        date_updated = Required(datetime.date)
        trove_id = Required(int)
        body = Optional(str)
        comment = Optional(str)
        tags = Set('Tag')
        has_image = Required(bool)
        @property
        def body_html(self):
            '''self.body as markdown-to-HTML.'''
            if not self.body: return None
            return markdown.markdown(self.body)
        @property
        def comment_html(self):
            '''self.comment as markdown-to-HTML.'''
            if not self.comment: return None
            return markdown.markdown(self.comment)
        @property
        def url(self):
            '''URL for the article detail page.'''
            return '/{}/{}/{}.html'.format(
                self.publication.key,
                self.pub_date.strftime('%Y-%m-%d'),
                self.key,
            )

    class Tag(db.Entity):
        key = PrimaryKey(str)
        title = Required(str)
        precis = Optional(str)
        category = Required(str)
        comment = Optional(str)
        articles = Set('Article')
        @property
        def comment_html(self):
            '''self.comment as markdown-to-HTML.'''
            if not self.comment: return None
            return markdown.markdown(self.comment)
        @property
        def url(self):
            '''URL for the tag overview page.'''
            return '/{}.html'.format(self.key)

    class Publication(db.Entity):
        key = PrimaryKey(str)
        title = Required(str)
        comment = Optional(str)
        articles = Set('Article')
        @property
        def comment_html(self):
            '''self.comment as markdown-to-HTML.'''
            if not self.comment: return None
            return markdown.markdown(self.comment)
        @property
        def url(self):
            '''URL for the publication overview page.'''
            return '/{}/'.format(self.key)

    db.generate_mapping(create_tables=True)

    ## Insert publications
    for path in glob.glob('publications/*.txt'):
        with open(path, 'r') as fp, db_session:
            attrs = {}
            section = 0
            for line in fp.readlines():
                if line[:4] == '----':
                    section += 1
                elif section == 0: # meta
                    key, value = meta_from(line)
                    if key == 'Title': attrs['title'] = value
                    elif key == 'Key': attrs['key'] = value
                    elif key == None: continue
                elif section == 1: # comment
                    if not 'comment' in attrs:
                        attrs['comment'] = ''
                    attrs['comment'] += line
            Publication(**attrs)

    ## Insert all tags into the database
    for path in glob.glob('tags/*.txt'):
        with open(path, 'r') as fp, db_session:
            attrs = {}
            section = 0
            for line in fp.readlines():
                if line[:4] == '----':
                    section += 1
                elif section == 0: # meta
                    key, value = meta_from(line)
                    if key == 'Title': attrs['title'] = value
                    elif key == 'Key': attrs['key'] = value
                    elif key == 'Category': attrs['category'] = value
                    elif key == 'Precis': attrs['precis'] = value
                    elif key == None: continue
                elif section == 1: # comment
                    if not 'comment' in attrs:
                        attrs['comment'] = ''
                    attrs['comment'] += line
            Tag(**attrs)

    ## Insert all articles into the database
    for path in glob.glob('articles/*.txt'):
        with open(path, 'r') as fp, db_session:
            attrs = {'tags': []}
            section = 0 #0: meta, 1: body, 2: comment
            for line in fp.readlines():
                if line[:4] == '----':
                    section += 1
                elif section == 0: # meta
                    key, value = meta_from(line)
                    if key == '#':
                        tag = get(t for t in Tag if t.key == value)
                        if not tag:
                            raise Exception('Missing description file for tag "#{}"'.format(value))
                        attrs['tags'].append(tag)
                    elif key == 'Title': attrs['title'] = value
                    elif key == 'Key': attrs['key'] = value
                    elif key == 'Category': attrs['category'] = value
                    elif key == 'Publication':
                        publication = get(p for p in Publication if p.key == value)
                        if not publication:
                            raise Exception('Missing description file for publication "{}"'.format(value))
                        attrs['publication'] = publication
                    elif key == 'Page': attrs['page'] = value
                    elif key == 'PubDate': attrs['pub_date'] = datetime.datetime.strptime(value, '%Y-%m-%d').date()
                    elif key == 'DateUpdated': attrs['date_updated'] = datetime.datetime.strptime(value, '%Y-%m-%d').date()
                    elif key == 'TroveID': attrs['trove_id'] = value
                    elif key == 'Precis': attrs['precis'] = value
                    elif key == None: continue
                    else:
                        raise Exception('Bad meta item {} in meta section'.format(line.rstrip()))
                elif section == 1: # body
                    if not 'body' in attrs:
                        attrs['body'] = ''
                    attrs['body'] += line
                elif section == 2: # comment
                    if not 'comment' in attrs:
                        attrs['comment'] = ''
                    attrs['comment'] += line
            attrs['has_image'] = os.path.exists('article-img/{}.jpg'.format(attrs['key']))
            Article(**attrs)
    # Second phase - use the items in the database to generate HTML files
    ## Create/clear the www folder
    try:
        shutil.rmtree('www')
    except FileNotFoundError:
        pass
    ## Copy over any static files
    shutil.copytree('static', 'www')
    shutil.copytree('article-img', 'www/article-img')
    ## Now generate some html
    ## TODO: I also need a sitemap.xml
    jenv = jinja2.Environment(loader=jinja2.FileSystemLoader('html'))
    def filter_dateformat(value, format='%A %e %B %Y'):
        return value.strftime(format)
    jenv.filters['dateformat'] = filter_dateformat
    with db_session:
        ## First generate the article pages
        for article in select(a for a in Article):
            template = jenv.get_template('article.html')
            html = template.render(article=article)
            path = 'www' + article.url
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w') as fp:
                fp.write(html)
        ## Then generate tag pages
        for tag in select(t for t in Tag):
            template = jenv.get_template('tag.html')
            html = template.render(
                tag=tag,
                articles=tag.articles.order_by(Article.pub_date, Article.publication, Article.page)
            )
            path = 'www' + tag.url
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w') as fp:
                fp.write(html)
        ## Publication index page
        for publication in select(p for p in Publication):
            template = jenv.get_template('publication.html')
            html = template.render(
                publication=publication,
                articles=publication.articles.order_by(Article.pub_date, Article.page)
            )
            path = 'www' + publication.url + 'index.html'
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w') as fp:
                fp.write(html)
        ## Now generate index page
        template = jenv.get_template('index.html')
        html = template.render(
            person_tags=select(t for t in Tag if t.category == 'Person').order_by(Tag.title),
            place_tags=select(t for t in Tag if t.category == 'Place').order_by(Tag.title),
            event_tags=select(t for t in Tag if t.category == 'Event').order_by(Tag.title),
            business_tags=select(t for t in Tag if t.category == 'Business').order_by(Tag.title),
            group_tags=select(t for t in Tag if t.category == 'Group').order_by(Tag.title),
            recent_articles=select(a for a in Article).order_by(desc(Article.date_updated))[:5],
            publications=select(p for p in Publication).order_by(Publication.title),
        )
        with open('www/index.html', 'w') as fp:
            fp.write(html)
        ## Recently Added
        template = jenv.get_template('recents.html')
        html = template.render(
            articles=select(a for a in Article).order_by(desc(Article.date_updated))[:20]
        )
        with open('www/recents.html', 'w') as fp:
            fp.write(html)
        ## To transcribe
        template = jenv.get_template('to_transcribe.html')
        html = template.render(
            articles=select(a for a in Article if a.body == '')
        )
        with open('www/to_transcribe.html', 'w') as fp:
            fp.write(html)
        ## 404 error page
        template = jenv.get_template('404error.html')
        html = template.render()
        with open('www/404error.html', 'w') as fp:
            fp.write(html)

if __name__ == '__main__':
    build()
