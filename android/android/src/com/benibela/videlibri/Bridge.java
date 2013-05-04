package com.benibela.videlibri;

import android.util.Log;

import java.util.Map;
import java.util.TreeMap;

public class Bridge {
    public static class Account{
        String libId, name, pass, prettyName;
        boolean extend;
        int extendDays;
        boolean history;
        @override boolean equals(Object o){
            if (!(o instanceof Account)) return  false;
            Account a = (Account) o;
            return  (a.libId == libId && a.prettyName == prettyName);
        }
    }

    public static class Book{
        String author;
        String title;
        Map<String, String> more = new TreeMap<String, String>();
    }

    static public native void VLInit(VideLibri videlibri);
    static public native String[] VLGetLibraries(); //id|pretty location|name|short name
  /*public native Account[] VLGetAccounts();
  public native void VLAddAccount(Account acc);
  public native void VLChangeAccount(Account oldacc, Account newacc);
  public native void VLDeleteAccount(Account acc);
  public native Book[] VLGetBooks(Account acc, boolean history);
  public native void VLUpdateAccount(Account acc);                */
    static public native void VLFinalize();


    //const libID: string; prettyName, aname, pass: string; extendType: TExtendType; extendDays:integer; history: boolean 

    //mock functions
    /*static public String[] VLGetLibraries(){
        return new String[]{"due_stb|Düsseldorf|Düsseldorfer Stadtbücherei|D s",
                "due_ulb|Düsseldorf|Düsseldorfer Unibib|D u",
                "ach_stb|Aachen|Aachener Stadtbücherei|A Stb" };
    } */
    static public Account[] VLGetAccounts(){
        return new Account[0];
    }
    static public void VLAddAccount(Account acc){

    }
    static public void VLChangeAccount(Account oldacc, Account newacc){

    }
    static public void VLDeleteAccount(Account acc){}
    static public Book[] VLGetBooks(Account acc, boolean history){return  new Book[0];}
    static public void VLUpdateAccount(Account acc){}



    static
    {
        try //from LCLActivity
        {
            Log.i("videlibri", "Trying to load liblclapp.so");
            System.loadLibrary("lclapp");
        }
        catch(UnsatisfiedLinkError ule)
        {
            Log.e("videlibri", "WARNING: Could not load liblclapp.so");
            ule.printStackTrace();
        }
    }
}
