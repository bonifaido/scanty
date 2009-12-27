require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-timestamps'

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'post'

configure do
	DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://blog.db")
  DataMapper.auto_upgrade!

	require 'ostruct'
	Blog = OpenStruct.new(
		:title => 'a scanty blog',
		:author => 'John Doe',
		:url_base => 'http://localhost:4567/',
		:admin_password => 'changeme',
		:admin_cookie_key => 'scanty_admin',
		:admin_cookie_value => '6736d976913ket58',
		:disqus_shortname => nil
	)
end

error do
	e = request.env['sinatra.error']
	puts e.to_s
	puts e.backtrace.join("\n")
	"Application error"
end

helpers do
	def admin?
		request.cookies[Blog.admin_cookie_key] == Blog.admin_cookie_value
	end

	def auth
		stop [ 401, 'Not authorized' ] unless admin?
	end
end

layout 'layout'

### Public

get '/' do
	posts = Post.all(:order => :created_at.desc, :limit => 10)
	erb :index, :locals => { :posts => posts }, :layout => false
end

get '/past/:year/:month/:day/:slug/' do
	post = Post.first(:slug => params[:slug])
	stop [ 404, "Page not found" ] unless post
	@title = post.title
	erb :post, :locals => { :post => post }
end

get '/past/:year/:month/:day/:slug' do
	redirect "/past/#{params[:year]}/#{params[:month]}/#{params[:day]}/#{params[:slug]}/", 301
end

get '/past' do
	posts = Post.all(:order => :created_at.desc)
	@title = "Archive"
	erb :archive, :locals => { :posts => posts }
end

get '/past/tags/:tag' do
	tag = params[:tag]
	posts = Post.all(:tags.like => "%#{tag}%", :limit => 30, :order => :created_at.desc)
	@title = "Posts tagged #{tag}"
	erb :tagged, :locals => { :posts => posts, :tag => tag }
end

get '/feed' do
	@posts = Post.all(:order => :created_at.desc, :limit => 10 )
	content_type 'application/atom+xml', :charset => 'utf-8'
	builder :feed
end

get '/rss' do
	redirect '/feed', 301
end

### Admin

get '/auth' do
	erb :auth
end

post '/auth' do
	set_cookie(Blog.admin_cookie_key, Blog.admin_cookie_value) if params[:password] == Blog.admin_password
	redirect '/'
end

get '/posts/new' do
	auth
	erb :edit, :locals => { :post => Post.new, :url => '/posts' }
end

post '/posts' do
	auth
	post = Post.new :title => params[:title], :tags => params[:tags], :body => params[:body], :slug => Post.make_slug(params[:title])
	post.save
	redirect post.url
end

get '/past/:year/:month/:day/:slug/edit' do
	auth
	post = Post.first(:slug => params[:slug])
	stop [ 404, "Page not found" ] unless post
	erb :edit, :locals => { :post => post, :url => post.url }
end

post '/past/:year/:month/:day/:slug/' do
	auth
	post = Post.first(:slug => params[:slug])
	stop [ 404, "Page not found" ] unless post
	post.title = params[:title]
	post.tags = params[:tags]
	post.body = params[:body]
	post.save
	redirect post.url
end
