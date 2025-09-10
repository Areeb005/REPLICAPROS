require('dotenv').config();
const express = require('express');
const sequelize = require('./config/dbConfig');
const mainRoutes = require('./routes/mainRoutes');
const nocache = require('nocache');
const cors = require('cors')
const path = require('path');
const fs = require('fs');
const https = require('https');



const app = express();
app.use(express.json());
app.use(nocache());
app.use(cors())

// HTTPS certificate options
const options = {
    key: fs.readFileSync("./SSL/private.key"),
    cert: fs.readFileSync("./SSL/certificate.crt"),
    ca: fs.readFileSync("./SSL/ca-bundle.crt") // optional but recommended
};

app.use('/api', mainRoutes);


app.get("/", (req, res) => {
    return res.status(200).json({ message: 'Server is up and running.' })
})

// app.use("/api/uploads", express.static(path.join(__dirname, "uploads")));



// {alter:true}
sequelize.sync().then(() => {
    https.createServer(options, app).listen(process.env.PORT, () => {
        console.log(`🔒 HTTPS Server running on port ${process.env.PORT}`);
    });

    // app.listen(process.env.PORT, () => {
    //     console.log(`🔒 HTTP Server running on port ${process.env.PORT}`);
    // });

}).catch(err => console.error('Database connection failed:', err));
