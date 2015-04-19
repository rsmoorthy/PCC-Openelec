import sqlite3

conn = sqlite3.connect('MyVideos90.db')

c = conn.cursor()
c.execute("select * from resumer")
print c.fetchone()

c.execute("SELECT * FROM path")
print c.fetchall()
c.execute("SELECT * FROM files")
print c.fetchall()
c.execute("SELECT * FROM bookmark")
print c.fetchall()
