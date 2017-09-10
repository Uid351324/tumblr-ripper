#!/usr/bin/env python
import json
import sys
import os
import sqlite3
import requests
from optparse import OptionParser
ADDTUMLR = '''INSERT OR REPLACE INTO `tumblr`(`name`,`url`,`update`,`status`) VALUES (?,?, datetime('now'), ?);'''
UPTUMBLR = '''update tumblr set `statusdif` = `status`, `status` = ?, `update`  = datetime('now') where `name` = ?'''
ADDPOST = '''INSERT OR IGNORE INTO `post`(`id`,`tumblr`,`type`,`slug`,`text`,`date`, `reblog`) VALUES (?,?,?, ?,?,?, ?);'''
ADDPIC = '''INSERT OR REPLACE INTO `pic`(`post`,`offset`,`url`,`thumb`) VALUES (?,?,?,?);'''
ADDREPOST = '''INSERT OR REPLACE INTO `repostsrc`(`tumblr`, `post`, `base`) VALUES (?, ?, ?);'''
UPREPOST = '''update repostsrc set `have`=1 where tumblr in (select url from tumblr);'''
UPPIC = '''UPDATE `post` SET `pic`=? WHERE `id`=?;'''

SELTUMBLR = '''select url from tumblr order by `update` asc limit 10;'''

def downloadJson(url, start):
	# conn = http.client.HTTPConnection(url)
	payload = {'start': start, 'num': 50}
	api = "/api/read/json"
	if url[-1] == "/":
		api = "api/read/json"
	res = requests.get(url + api, params=payload)
	# conn.request("GET", '/api/read/json')
	# res = conn.getresponse()

	# print(res.status, res.reason)
	# if res.status == 200:
	print("sttus: ", res.status_code)
	data = res.text
	# print(data[22:-2])
	posts = None
	if res.status_code == 200:
		posts = json.loads(data[22:-2])

	return (posts, res.status_code)
	# else:
		# data = res

def parsePosts(posts, cursor, status, url):
	if status != 200:
		name = url.split("/")[2].split(".")[0]
		print("ERRPR:", status, name)
		# cursor.execute(ADDTUMLR, (name , "http://" + name + ".tumblr.com", status))
		cursor.execute(UPTUMBLR, (status, name))
		return (0, 0)
	print("size ", len(posts["posts"]))
	print("start ", posts["posts-start"])
	print("total ", posts["posts-total"])
	name = posts["tumblelog"]["name"]
	# cursor.execute(ADDTUMLR, (name , "http://" + name + ".tumblr.com", status))
	cursor.execute(UPTUMBLR, (status, name))
	count = 0
	affected = 0
	for post in posts["posts"]:
		print (post["id"])
		ptype = post["type"]
		assert ptype in ["answer", "photo", "regular", "link", "video", "quote", "audio", "conversation"]
		if ptype == "answer":
			text = '<p class="question">' + post["question"] + '</p><p class="answer">' + post["answer"] + '</p>'
		elif ptype == "photo":
			text =  post["photo-caption"] 
		elif ptype == "regular":
			text =  post["regular-body"]
		elif ptype == "link":
			text = str(post["link-description"] or 'none')+'<br><p class="link"><a href="'+ post["link-url"] + '">' + str(post["link-text"] or 'none') + '</a></p>'
		elif ptype == "video":
			text =  post["video-caption"]+str(post["video-player"])
		elif ptype == "quote":
			text =  '<p class="question">' + post["quote-text"] + '</p><p class="answer">' + post["quote-source"] + '</p>'
		elif ptype == "audio":
			text =  post["audio-caption"]+str(post["audio-player"])
		elif ptype == "conversation":
			text =  post["conversation-text"]
			

		reblog = 0
		if 'tumblr_blog' in text:
			reblog = 1
			src = text.split('/post/')[0].split('href="')[-1]
			cursor.execute(ADDREPOST, (src,post["id"], name ))
			print ("reblog", src)



		cursor.execute(ADDPOST, (post["id"], name, ptype, post["slug"], text , post["date-gmt"] , reblog))
		print('added ', cursor.rowcount)
		affected += cursor.rowcount
		if ptype == "photo":
			cursor.execute(ADDPIC,(post["id"], 1, post["photo-url-1280"], post["photo-url-250"]))
			if "photo-link-url" in post:
				cursor.execute(ADDPIC,(post["id"], 0, post["photo-link-url"], post["photo-url-250"]))
			print (post["id"])
			cursor.execute(UPPIC, ( 'pic', post["id"],  ) )
			# print(len(post["photos"]))
			for pic in post["photos"]:
				offset = (pic["offset"])[1]
				cursor.execute(ADDPIC,(post["id"], offset, pic["photo-url-1280"], pic["photo-url-250"]))
				# print((post["id"], offset, pic["photo-url-1280"]))
		if ptype == "video":
			cursor.execute(UPPIC,('vid', post["id"] ))
		# if not affected:
		# 	break
		count += 1
		# print ("\t"+post["slug"])
		# print ("\t"+post["type"])
		# print ("\t" + post["photo-caption"])
	cursor.execute(UPREPOST)
	return (count, affected)

def getPost(url, conn , add):
	start = 0 
	cursor = conn.cursor()
	(posts, status) = downloadJson(url, start)
	(parsed, affected) = parsePosts(posts, cursor, status , url)
	print("start ", start, " parsed", parsed)
	conn.commit()
	while parsed > 0:
		if affected < parsed and not add:
			print("break ", affected, " / ", parsed)
			break
		start += parsed
		(posts, status) = downloadJson(url, start)
		(parsed, affected) = parsePosts(posts, cursor, status , url )
		print("start ", start, " parsed", parsed, " affected ", affected)
		conn.commit()

def main():

	conn = sqlite3.connect('data/data.tum.db')
	parser = OptionParser()
	parser.add_option("-a", "--add", dest="add")
	parser.add_option("-u", "--update", action="store_true", dest="update", default=False)
	parser.add_option("-i","--ignore", action="store_true", dest="ignore", default=False)
	(options, args) = parser.parse_args()
	if options.ignore:
		print("ignore")
		global ADDPOST
		ADDPOST = '''INSERT OR IGNORE INTO `post`(`id`,`tumblr`,`type`,`slug`,`text`,`date`,`reblog`,  `new`) VALUES (?,?,?, ?,?,?, ?,0);'''

	if options.add:
		print("ADD")
		name = options.add.split("/")[2].split(".")[0]
		cursor = conn.cursor()
		cursor.execute(ADDTUMLR, (name , "http://" + name + ".tumblr.com", 999))
		getPost(options.add, conn,  True)
	elif options.update:
		print("UPDATE")
		cursor = conn.cursor()
		result = cursor.execute(SELTUMBLR)
		for tumblr in result.fetchall():
			print("UPDATE ", tumblr[0])
			getPost(tumblr[0], conn,  False)
	else:
		print("noAdd")
	conn.close()
	# posts = downloadJson()
	# parsePosts(posts)
	# print(json)


if __name__ == '__main__':
	main()