import datetime
import fnmatch
import os
import shutil

import jinja2
import markdown
from pony import orm

db = orm.Database()

# Helper functions
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

def generate_template(jenv, template_name, path, **kwargs):
    template = jenv.get_template(template_name)
    html = template.render(**kwargs)
    path = 'www' + path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as fp:
        fp.write(html)

# Model classes
class Article(db.Entity):
    key = orm.PrimaryKey(str)
    title = orm.Required(str)
    precis = orm.Optional(str)
    category = orm.Required(str)
    first_insertion_date = orm.Required(datetime.date)
    insertions = orm.Set('Insertion')
    date_updated = orm.Required(datetime.date)
    body = orm.Optional(str)
    comment = orm.Optional(str)
    tags = orm.Set('Tag')
    has_image = orm.Required(bool)
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
            self.first_insertion.publication.key,
            self.first_insertion.date.strftime('%Y-%m-%d'),
            self.key,
        )
    @property
    def first_insertion(self):
        return self.insertions.order_by(Insertion.date).first()

class Tag(db.Entity):
    key = orm.PrimaryKey(str)
    title = orm.Required(str)
    precis = orm.Optional(str)
    category = orm.Required(str)
    comment = orm.Optional(str)
    articles = orm.Set('Article')
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
    key = orm.PrimaryKey(str)
    title = orm.Required(str)
    comment = orm.Optional(str)
    insertions = orm.Set('Insertion')
    @property
    def comment_html(self):
        '''self.comment as markdown-to-HTML.'''
        if not self.comment: return None
        return markdown.markdown(self.comment)
    @property
    def url(self):
        '''URL for the publication overview page.'''
        return '/{}/'.format(self.key)

class Insertion(db.Entity):
    article = orm.Required('Article')
    date = orm.Required(datetime.date)
    publication = orm.Required('Publication')
    page = orm.Required(str)
    trove_id = orm.Required(int)

class YearSummary(db.Entity):
    year = orm.Required(int)
    body = orm.Required(str)
    @property
    def body_html(self):
        '''self.body as markdown-to-HTML.'''
        if not self.body: return None
        return markdown.markdown(self.body)

# Build system
def build_database(db):
    '''Load all items into an sqlite3 database.'''
    db.generate_mapping(create_tables=True)

    ## Insert publications
    for root, dirnames, filenames in os.walk('publications'):
        for filename in fnmatch.filter(filenames, '*.txt'):
            with open(os.path.join(root, filename), 'r') as fp, orm.db_session:
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
    for root, dirnames, filenames in os.walk('tags'):
        for filename in fnmatch.filter(filenames, '*.txt'):
            with open(os.path.join(root, filename), 'r') as fp, orm.db_session:
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
    for root, dirnames, filenames in os.walk('articles'):
        for filename in fnmatch.filter(filenames, '*.txt'):
            with open(os.path.join(root, filename), 'r') as fp, orm.db_session:
                attrs = {'tags': []}
                section = 0 #0: meta, 1: body, 2: comment
                insertions = []
                for line in fp.readlines():
                    if line[:4] == '----':
                        section += 1
                    elif section == 0: # meta
                        key, value = meta_from(line)
                        if key == '#':
                            tag = orm.get(t for t in Tag if t.key == value)
                            if not tag:
                                raise Exception('Missing description file for tag "#{}" in article {}'.format(value, filename))
                            attrs['tags'].append(tag)
                        elif key == 'Title': attrs['title'] = value
                        elif key == 'Key': attrs['key'] = value
                        elif key == 'Category': attrs['category'] = value
                        elif key == 'Insertion':
                            comps = list(map(str.strip, value.split('|')))
                            if len(comps) != 4:
                                raise Exception('Bad Insertion item for article {}'.format(filename))
                            assert(len(comps) == 4)
                            insertions.append(comps)
                        elif key == 'DateUpdated': attrs['date_updated'] = datetime.datetime.strptime(value, '%Y-%m-%d').date()
                        elif key == 'Precis': attrs['precis'] = value
                        elif key == None: continue
                        else:
                            raise Exception('Bad meta item {} in meta section for article {}'.format(line.rstrip(), filename))
                    elif section == 1: # body
                        if not 'body' in attrs:
                            attrs['body'] = ''
                        attrs['body'] += line
                    elif section == 2: # comment
                        if not 'comment' in attrs:
                            attrs['comment'] = ''
                        attrs['comment'] += line
                attrs['has_image'] = os.path.exists('article-img/{}.jpg'.format(attrs['key']))
                attrs['first_insertion_date'] = datetime.datetime.strptime(insertions[0][0], '%Y-%m-%d').date()
                article = Article(**attrs)
                for (date, publication, page, trove_id) in insertions:
                    date = datetime.datetime.strptime(date, '%Y-%m-%d').date()
                    publication = orm.get(p for p in Publication if p.key == publication)
                    if not publication:
                        raise Exception('Missing description file for publication "{}"'.format(value))
                    insertion = Insertion(article=article, date=date, publication=publication, page=page, trove_id=trove_id)
                    article.insertions.add(insertion)

    ## Yearly Summaries
    for root, dirnames, filenames in os.walk('years'):
        for filename in fnmatch.filter(filenames, '*.txt'):
            with open(os.path.join(root, filename), 'r') as fp, orm.db_session:
                attrs = {'body': ''}
                section = 0 #0: meta, 1: body
                for line in fp.readlines():
                    if line[:4] == '----':
                        section += 1
                    elif section == 0:
                        key, value = meta_from(line)
                        if key == 'Year': attrs['year'] = int(value)
                        elif key == None: continue
                        else:
                            raise Exception('Bad meta item {} in meta section for article {}'.format(line.rstrip(), filename))
                    elif section == 1:
                        attrs['body'] += line
                YearSummary(**attrs)


def build_html(db):
    '''Use the items in the database to generate HTML files.'''
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
    with orm.db_session:
        ## First generate the article pages
        for article in orm.select(a for a in Article):
            generate_template(jenv, 'article.html', article.url,
                article=article,
                insertions=article.insertions.order_by(Insertion.date)
            )
        ## Then generate tag pages
        for tag in orm.select(t for t in Tag):
            generate_template(jenv, 'tag.html', tag.url,
                tag=tag,
                articles=tag.articles.order_by(Article.first_insertion_date)
            )
        ## Publication index page
        for publication in orm.select(p for p in Publication):
            generate_template(jenv, 'publication.html', publication.url + 'index.html',
                publication=publication,
                insertions=publication.insertions.order_by(Insertion.date)
            )
        ## Now generate index page
        generate_template(jenv, 'index.html', '/index.html',
            person_tags=orm.select(t for t in Tag if t.category == 'Person').order_by(Tag.title),
            place_tags=orm.select(t for t in Tag if t.category == 'Place').order_by(Tag.title),
            event_tags=orm.select(t for t in Tag if t.category == 'Event').order_by(Tag.title),
            business_tags=orm.select(t for t in Tag if t.category == 'Business').order_by(Tag.title),
            group_tags=orm.select(t for t in Tag if t.category == 'Group').order_by(Tag.title),
            recent_articles=orm.select(a for a in Article).order_by(orm.desc(Article.date_updated))[:5],
            publications=orm.select(p for p in Publication).order_by(Publication.title),
            total_articles=orm.select(a for a in Article).count(),
            latest_date=orm.select(i for i in Insertion).order_by(orm.desc(Insertion.date)).first().date,
            year_summaries=orm.select(s for s in YearSummary).order_by(YearSummary.year),
        )
        ## Yearly Summaries
        for summary in orm.select(s for s in YearSummary):
            generate_template(jenv, 'year.html', '/' + str(summary.year) + '/index.html',
                summary=summary)
        ## Recently Added
        generate_template(jenv, 'recents.html', '/recents.html',
            articles=orm.select(a for a in Article).order_by(orm.desc(Article.date_updated))[:20]
        )
        ## To transcribe
        generate_template(jenv, 'to_transcribe.html', '/to_transcribe.html',
            articles=orm.select(a for a in Article if a.body == '')
        )
        ## 404 error page
        generate_template(jenv, '404error.html', '/404error.html')

if __name__ == '__main__':
    db.bind('sqlite', ':memory:')
    # orm.sql_debug(True)
    build_database(db)
    build_html(db)
