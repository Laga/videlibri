package de.benibela.videlibri;

import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Xml;
import android.widget.ListView;
import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlPullParserException;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;

/**
 * Created with IntelliJ IDEA.
 * User: benito
 * Date: 6/6/13
 * Time: 2:36 PM
 * To change this template use File | Settings | File Templates.
 */
public class About extends VideLibriBaseActivity {
    XmlPullParser parser;
    ArrayList<BookDetails.Details> details;
    BookDetails.Details curDetails;
    String firstVersion = "";

    void parseChangelog() throws IOException, XmlPullParserException {
        parser.require(XmlPullParser.START_TAG, null, "changelog");
        while (parser.next() != XmlPullParser.END_TAG) {
            if (parser.getEventType() != XmlPullParser.START_TAG)
                continue;
            if ("build".equals(parser.getName())) parseBuild();
            else skip();
        }
    }

    void parseBuild() throws IOException, XmlPullParserException {
        String version = parser.getAttributeValue(null, "version");
        if ("".equals(firstVersion)) firstVersion = version;

        curDetails = new BookDetails.Details("Version:  "+(Util.strToIntDef(version, 0) / 1000.0)+ " vom "+parser.getAttributeValue(null, "date"), "");
        details.add(curDetails);
        while (parser.next() != XmlPullParser.END_TAG) {
            if (parser.getEventType() != XmlPullParser.START_TAG)
                continue;
            if ("add".equals(parser.getName())) curDetails.data = curDetails.data + "\n" + " (+) " + parseText();
            else if ("change".equals(parser.getName())) curDetails.data = curDetails.data + "\n" + " (*) " + parseText();
            else if ("fix".equals(parser.getName())) curDetails.data = curDetails.data + "\n" + " (f) " + parseText();
            else skip();
        }
    }

    String parseText() throws IOException, XmlPullParserException {
        String result = "";
        while (parser.next() != XmlPullParser.END_TAG)
            if (parser.getEventType() == XmlPullParser.TEXT)
                result += parser.getText();
        return result;
    }

    //from http://developer.android.com/training/basics/network-ops/xml.html
    private void skip() throws XmlPullParserException, IOException {
        if (parser.getEventType() != XmlPullParser.START_TAG) {
            throw new IllegalStateException();
        }
        int depth = 1;
        while (depth != 0) {
            switch (parser.next()) {
                case XmlPullParser.END_TAG:
                    depth--;
                    break;
                case XmlPullParser.START_TAG:
                    depth++;
                    break;
            }
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);    //To change body of overridden methods use File | Settings | File Templates.
        setContentView(R.layout.bookdetails);
        ListView lv = (ListView) findViewById(R.id.bookdetailsview);

        details = new ArrayList<BookDetails.Details>();
        parser = Xml.newPullParser();
        try {
            parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false);
            InputStream file = this.getAssets().open("changelog.xml");
            parser.setInput(file, null);
            parser.nextTag();
            parseChangelog();
        } catch (XmlPullParserException e) {
            e.printStackTrace();  //To change body of catch statement use File | Settings | File Templates.
        } catch (IOException e) {
            e.printStackTrace();  //To change body of catch statement use File | Settings | File Templates.
        }


        try {
            details.add(0, new BookDetails.Details("Version", "VideLibri "+getPackageManager().getPackageInfo("de.benibela.videlibri", 0).versionName ));
        } catch (PackageManager.NameNotFoundException e) {
            details.add(0, new BookDetails.Details("Version", "VideLibri "+(Util.strToIntDef(firstVersion, 0) / 1000.0)  + " ??"));
        }
        details.add(1, new BookDetails.Details("Homepage", "http://videlibri.sourceforge.net"));
        details.add(2, new BookDetails.Details("Quellcode", "http://sourceforge.net/p/videlibri/code/ci/trunks/tree/"));



        lv.setAdapter(new BookDetails.BookDetailsAdapter(this, details, new Bridge.Book()));
    }
}