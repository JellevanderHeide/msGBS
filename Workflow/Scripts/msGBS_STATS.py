#!/usr/bin/env python
import pysam
import argparse
import nested_dict
import re
def parse_args():
    """Pass command line arguments"""
    parser = argparse.ArgumentParser(description='Remove PCR duplicates from bam file')
    #input files
    parser.add_argument('-i', '--input',
                        help='bam input file')
    parser.add_argument('-o', '--output',
                        help='output csv file')
    args = parser.parse_args()
    return args

def get_stats(args):
    """get stats based on bam file"""
    mapping_dict = nested_dict.nested_dict()
    try:
        handle = pysam.AlignmentFile(args.input, 'r')
    except OSError:
        print('error')
    #Samples can be added from several lanes, which will results in different read groups
    #in order to only account for samples here, make a dict mapping RG_ID to sample

    RG_to_sample = dict([(r['ID'],r['SM']) for r in handle.header['RG']])
    count = 0
    for read in handle:
        count += 1
        if not count %100000:
            print('%s reads processed' % count)
        if not read.is_duplicate and not read.is_qcfail:
            #make dict of read tag objects
            tag_dict = dict(read.tags)
            try:
                sample = RG_to_sample[tag_dict['RG']]
            except KeyError:
                # inserted this to cope with the fact that there were two lanes
                try:
                    tmpsample = tag_dict['RG']
                    tmpsamplelist =list(tmpsample)
                    tmpsamplelist[10] = '2'
                    sample = ''.join(tmpsamplelist)
                    print(tmpsample)
                except TypeError:
                    sample = 'unknown'
                    print("unknown samples detected ")
            try:
                mapping_dict['total'][sample] += 1
            except TypeError:
                mapping_dict['total'][sample] = 1
            try:
                mapping_dict[read.reference_name][sample] += 1
            except TypeError:
                mapping_dict[read.reference_name][sample] = 1
    return mapping_dict


def write_output(mapping_dict, args):
    """write output according to specifications"""
    handle = pysam.AlignmentFile(args.input, 'r')
    out_handle = open(args.output,'w')
    header = ['Species','Locus']
    sample_order = []
    for rg_dict in handle.header['RG']:
        header.append(rg_dict['SM'])
        sample_order.append(rg_dict['SM'])
    out_handle.write('\t'.join(header)+'\n')
    for contig in handle.header['SQ']:
        contig_name = contig['SN']
        out_line = ['_'.join(contig_name.split('_')[:-1]), contig_name]
        if contig_name in mapping_dict:
            # and contig_name not in mapping_dict['discard']: #to get all mono data
            subdict = mapping_dict[contig['SN']]
            if sum(subdict.values()) > 10:
                # Dit is het totaal aantal counts over alle samples van de betreffende contig #
                for sample in sample_order:
                    if sample in subdict:
                        out_line.append(str(subdict[sample]))
                    else:
                        out_line.append('0')
                out_handle.write('\t'.join(out_line)+'\n')

    out_handle.close()


def main():
    """main function loop"""
    #1 get command line arguments
    args = parse_args()
    mapping_dict = get_stats(args)
    write_output(mapping_dict,args)

if __name__ == '__main__':
    main()